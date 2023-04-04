#!/not-executable/python3
import collections
import datetime as dt
import json
import os
import re
import requests
import sys
import time
from typing import Dict, List, Optional


# ===== HTTP request error classes =====

class UnexpectedHTTPResponseError(requests.exceptions.HTTPError):
    """The HTTP response code which was received was unexpected."""


class StateError(requests.exceptions.RequestException):
    """Some error in the state management of Toggl Track has occurred.
    Ideally the specific error will be represented as a derived class."""


class MissingAuthorizationError(StateError):
    """The authorization information needed to make a request was missing.
    Note that different requests have different authorization needs,
    so while some of the information may be specified, what we needed
    right now wasn't."""


# ===== Toggl Track client authentication data =====

class Auth(object):

    def __init__(self, *, email=None, password=None, api_token=None):
        self.email = email
        self.password = password
        self.api_token = api_token

    def __eq__(self, other):
        return (isinstance(self, Auth) and isinstance(other, Auth) and
                self.email == other.email and
                self.password == other.password and
                self.api_token == other.api_token)

    def clone(self):
        return self.__class__(**self.__dict__)


# ===== Common caching code =====

class ObjectCache(object):
    """A common class for caching objects by ID."""

    def __init__(self):
        self.__all = None
        self.__map = {}

    def full_list(self):
        assert self.has_full_list()
        return self.__all

    def has_full_list(self):
        return self.__all is not None

    def record_full_list(self):
        self.__all = tuple(self.__map.values())

    def has_id(self, id):
        return id in self.__map

    def get_id(self, id):
        return self.__map[id]

    def add_id(self, id, value):
        self.__map[id] = value

    def populate(self, items, *, create, get_id=None, **kwargs):
        if get_id is None:
            def get_id(data):
                return int(data['id'])
        for data in items:
            id = get_id(data)
            if not self.has_id(id):
                self.add_id(id, create(data, **kwargs))
        self.record_full_list()


# ===== Toggl Track client =====

class Method(object):
    """HTTP method names"""

    GET = 'GET'
    POST = 'POST'
    DELETE = 'DELETE'


class TogglTrack(object):
    """Client for access to Toggl Track."""

    AUTH_COOKIE_NAME = '__Host-timer-session'

    def __init__(self, *, auth=Auth(), email=None, password=None,
                 api_token=None):
        self.__auth = auth
        if email is not None:
            self.__auth.email = email
        if password is not None:
            self.__auth.password = password
        if api_token is not None:
            self.__auth.api_token = api_token
        self.__session = requests.Session()
        self.__default_workspace_id = None
        self.__workspaces = ObjectCache()

    def __del__(self):
        # This generates noise from the `copy` module at Python shutdown:
        # self.deauthenticate()
        pass

    def __repr__(self) -> str:
        return f"{type(self).__name__}(...)"

    def __eq__(self, other) -> bool:
        return (isinstance(self, TogglTrack) and isinstance(other, TogglTrack)
                and self.__auth == other.__auth)

    # HTTP request helpers

    def _make_basic_request(self, *, method=Method.GET, url,
                            accept_codes={requests.codes.ok},
                            extra_headers={}, **kwargs) \
            -> requests.models.Response:
        headers = {
            "accept": "application/json",
            **extra_headers
        }
        response, delay = None, 0.25
        while response is None:
            response = self.__session.request(method=method, url=url,
                                              headers=headers, **kwargs)
            if response.status_code == requests.codes.TOO_MANY_REQUESTS:
                time.sleep(delay)
                response, delay = None, 2*delay
        if response.status_code not in accept_codes:
            # try normal response error mechanism...
            response.raise_for_status()
            # ...otherwise generate our own exception
            raise UnexpectedHTTPResponseError(
                "Unexpected status: {code} {reason} for url: {url}".format(
                    code=response.status_code, reason=response.reason,
                    url=url),
                response=response)
        return response

    def _make_auth_request(self, *, username, password,
                           extra_headers={}, **kwargs) \
            -> requests.models.Response:
        response = self._make_basic_request(
            auth=requests.auth.HTTPBasicAuth(username, password),
            extra_headers=extra_headers, **kwargs)
        return response

    def _make_cookie_request(self, **kwargs) \
            -> requests.models.Response:
        if not self.has_cookie():
            raise MissingAuthorizationError("Cookie is not present.")
        return self._make_basic_request(**kwargs)

    # authentication-related functionality

    @property
    def auth(self) -> Auth:
        return self.__auth.clone()

    def has_cookie(self) -> bool:
        return self.AUTH_COOKIE_NAME in self.__session.cookies

    def is_cookie_valid(self) -> bool:
        if not self.has_cookie():
            return False
        url = "https://api.track.toggl.com/api/v9/me/logged"
        response = self._make_cookie_request(
            method=Method.GET, url=url,
            accept_codes={requests.codes.ok,
                          requests.codes.unauthorized,
                          requests.codes.forbidden})
        return response.status_code == requests.codes.ok

    def _create_cookie(self) -> Optional[Auth]:
        url = "https://api.track.toggl.com/api/v9/me/sessions"
        if self.__auth.api_token is not None:
            try:
                response = self._make_auth_request(
                    method=Method.POST, url=url,
                    username=self.__auth.api_token, password='api_token')
                self.__auth.api_token = response.json()['api_token']
                return self.__auth
            except requests.exceptions.HTTPError:
                pass  # assume the token is bad but email+password may work
        if (self.__auth.email is not None
                and self.__auth.password is not None):
            response = self._make_auth_request(
                method=Method.POST, url=url,
                username=self.__auth.email, password=self.__auth.password)
            self.__auth.api_token = response.json()['api_token']
            return self.__auth
        return None

    def authenticate(self, *, allow_user_input=True) -> Optional[Auth]:
        if self.is_cookie_valid():
            return None
        auth = self._create_cookie()
        if self.is_cookie_valid():  # is the check even needed?
            return auth
        raise RuntimeError("Could not get or create valid auth data.")

    def deauthenticate(self):
        if self.has_cookie():
            url = "https://api.track.toggl.com/api/v9/me/sessions"
            try:
                self._make_cookie_request(
                    method=Method.DELETE, url=url)
            finally:
                self.__session.cookies.pop(self.AUTH_COOKIE_NAME)

    # accessing objects

    def _cache_me(self):
        url = "https://api.track.toggl.com/api/v9/me"
        response = self._make_cookie_request(method=Method.GET, url=url)
        json = response.json()
        self.__default_workspace_id = json['default_workspace_id']

    def organizations(self) -> "List[Organization]":
        url = "https://api.track.toggl.com/api/v9/me/organizations"
        response = self._make_cookie_request(method=Method.GET, url=url)
        json = response.json()
        return [Organization._from_json(org_data, toggl_track=self)
                for org_data in json]

    def workspaces(self) -> "List[Workspace]":
        if not self.__workspaces.has_full_list():
            url = "https://api.track.toggl.com/api/v9/me/workspaces"
            response = self._make_cookie_request(method=Method.GET, url=url)
            json = response.json()
            # create new objects for any data not already cached
            self.__workspaces.populate(
                json, create=Workspace._from_json, toggl_track=self)
        return self.__workspaces.full_list()

    def workspace(self, *, workspace_id=None) -> "Optional[Workspace]":
        if workspace_id is None:
            workspace_id = self.workspace_id
        assert type(workspace_id) == int
        if self.__workspaces.has_id(workspace_id):
            return self.__workspaces.get_id(workspace_id)
        url = f"https://api.track.toggl.com/api/v9/workspaces/{workspace_id}"
        try:
            response = self._make_cookie_request(method=Method.GET, url=url)
            ws = Workspace._from_json(response.json(), toggl_track=self)
            self.__workspaces.add_id(workspace_id, ws)
            return ws
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == requests.codes.FORBIDDEN:
                return None  # assume we just can't (even)
            raise

    @property
    def workspace_id(self) -> str:
        if self.__default_workspace_id is not None:
            return self.__default_workspace_id
        self._cache_me()
        assert self.__default_workspace_id is not None
        return self.__default_workspace_id

    def time_entries(self, *, start, end) -> "List[TimeEntry]":
        url = "https://api.track.toggl.com/api/v9/me/time_entries"
        response = self._make_cookie_request(
            method=Method.GET, url=url,
            params={'start_date': start.isoformat(),
                    'end_date': end.isoformat()})
        json = response.json()
        return [
            TimeEntry._from_json(
                entry_data, toggl_track=self,
                workspace=self.workspace(
                    workspace_id=entry_data['workspace_id']))
            for entry_data in json
        ]


# ===== Base class for all Toggl Track objects =====


class TtObject(object):
    """Any object in Toggl Track."""

    def __init__(self, *, json, toggl_track: Optional[TogglTrack] = None):
        self.__json = json
        self.__tt = toggl_track
        self.__id = self.__json['id']

    def __str__(self) -> str:
        return f"{type(self).__name__}(id={self.id!r})"

    def __repr__(self) -> str:
        return f"{type(self).__name__}(json={self.__json!r})"

    def __eq__(self, other) -> bool:
        return (isinstance(self, TtObject) and
                isinstance(other, TtObject) and
                type(self) == type(other) and
                self.__id is not None and
                self.__id == other.__id)

    @classmethod
    def _from_json(cls, json: str, **kwargs):
        return cls(json=json, **kwargs)

    @property
    def _json(self):
        return self.__json

    def _get_property(self, *keys):
        try:
            node = self._json
            for key in keys:
                node = node[key]
            return node
        except KeyError:
            return None  # allow KeyError (but not TypeError)

    @property
    def id(self):
        return self.__id

    @property
    def toggl_track(self) -> Optional[TogglTrack]:
        return self.__tt


class TtNamedObject(TtObject):
    """Any named object in Toggl Track."""

    def __str__(self) -> str:
        return f"{type(self).__name__}(id={self.id!r}, name={self.name!r})"

    @property
    def name(self) -> str:
        return self._get_property('name')


# ===== Specific Toggl Track objects =====


class Organization(TtNamedObject):
    """An organization in Toggl Track."""


class Workspace(TtNamedObject):
    """A workspace in Toggl Track."""

    def __init__(self, *, json, toggl_track=None):
        super().__init__(json=json, toggl_track=toggl_track)
        self.__projects = ObjectCache()
        self.__clients = ObjectCache()
        self.__tags = ObjectCache()

    def projects(self) -> "List[Project]":
        if not self.__projects.has_full_list():
            url = (f"https://api.track.toggl.com/api/v9/workspaces/{self.id}"
                   f"/projects")
            assert self.toggl_track is not None
            response = self.toggl_track._make_cookie_request(
                method=Method.GET, url=url)
            json = response.json()
            # create new objects for any data not already cached
            self.__projects.populate(
                json, create=Project._from_json, toggl_track=self)
        return self.__projects.full_list()

    def project(self, *, project_id) -> "Optional[Project]":
        assert type(project_id) == int
        if self.__projects.has_id(project_id):
            return self.__projects.get_id(project_id)
        url = (f"https://api.track.toggl.com/api/v9/workspaces/{self.id}"
               f"/projects/{project_id}")
        try:
            assert self.toggl_track is not None
            response = self.toggl_track._make_cookie_request(
                method=Method.GET, url=url)
            pr = Project._from_json(response.json(), toggl_track=self)
            self.__projects.add_id(project_id, pr)
            return pr
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == requests.codes.NOT_FOUND:
                return None
            raise

    def clients(self) -> "List[Client]":
        if not self.__clients.has_full_list():
            url = (f"https://api.track.toggl.com/api/v9/workspaces/{self.id}"
                   f"/clients")
            assert self.toggl_track is not None
            response = self.toggl_track._make_cookie_request(
                method=Method.GET, url=url)
            json = response.json()
            # create new objects for any data not already cached
            self.__clients.populate(
                json, create=Client._from_json, toggl_track=self)
        return self.__clients.full_list()

    def client(self, *, client_id) -> "Optional[Client]":
        if self.__clients.has_id(client_id):
            return self.__clients.get_id(client_id)
        url = (f"https://api.track.toggl.com/api/v9/workspaces/{self.id}"
               f"/clients/{client_id}")
        try:
            assert self.toggl_track is not None
            response = self.toggl_track._make_cookie_request(
                method=Method.GET, url=url)
            cl = Client._from_json(response.json(), toggl_track=self)
            self.__clients.add_id(client_id, cl)
            return cl
        except requests.exceptions.HTTPError as e:
            # 500 Internal Server Error is what's actually returned
            if (e.response.status_code == requests.codes.INTERNAL_SERVER_ERROR
                    or e.response.status_code == requests.codes.NOT_FOUND):
                return None
            raise

    def tags(self) -> "List[Tag]":
        if not self.__tags.has_full_list():
            url = (f"https://api.track.toggl.com/api/v9/workspaces/{self.id}"
                   f"/tags")
            assert self.toggl_track is not None
            response = self.toggl_track._make_cookie_request(
                method=Method.GET, url=url)
            json = response.json()
            # create new objects for any data not already cached
            self.__tags.populate(
                json, create=Tag._from_json, toggl_track=self)
        return self.__tags.full_list()

    def tag(self, *, tag_id) -> "Optional[Tag]":
        if self.__tags.has_id(tag_id):
            return self.__tags.get_id(tag_id)
        # There is no documented v9 API for looking up a tag by ID.
        self.tags()  # call for its side effects
        if self.__tags.has_id(tag_id):
            return self.__tags.get_id(tag_id)
        return None


class Project(TtNamedObject):
    """A project in Toggl Track."""

    def __str__(self) -> str:
        return (f"{type(self).__name__}(id={self.id!r}, name={self.name!r},"
                f"  active={self.active!r})")

    @property
    def active(self) -> bool:
        return self._get_property('active')


class Client(TtNamedObject):
    """A client in Toggl Track."""

    def __str__(self) -> str:
        return (f"{type(self).__name__}(id={self.id!r}, name={self.name!r},"
                f" archived={self.archived!r})")

    @property
    def archived(self) -> bool:
        return self._get_property('archived')


class Tag(TtNamedObject):
    """A tag in Toggl Track."""


class TimeEntry(TtObject):
    """A time entry in Toggl Track."""

    def __init__(self, *, json, toggl_track=None, workspace=None):
        super().__init__(json=json, toggl_track=toggl_track)
        if workspace is not None:
            self.__ws = workspace
        elif toggl_track is not None:
            self.__ws = toggl_track.workspace(workspace_id=self.workspace_id)

    def __str__(self) -> str:
        return (f"{type(self).__name__}(id={self.id!r},"
                f" description={self.description!r})")

    @property
    def description(self) -> str:
        return self._get_property('description')

    @property
    def start(self) -> dt.datetime:
        return dt.datetime.fromisoformat(
            re.sub(r'Z$', '+00:00', self._get_property('start')))

    @property
    def end(self) -> Optional[dt.datetime]:
        end = self._get_property('stop')
        if end is None:
            return None
        return dt.datetime.fromisoformat(
            re.sub(r'Z$', '+00:00', end))

    @property
    def duration(self) -> dt.timedelta:
        return dt.timedelta(seconds=self._get_property('duration'))

    @property
    def workspace_id(self) -> str:
        return self._get_property('workspace_id')

    @property
    def project_id(self) -> Optional[str]:
        return self._get_property('project_id')

    @property
    def workspace(self) -> Workspace:
        return self.__ws

    @property
    def project(self) -> Optional[Project]:
        pr_id = self.project_id
        if pr_id is None:
            return None
        return self.workspace.project(project_id=pr_id)


# ===== managing saved authentication and the client object =====


def get_auth_file_name() -> str:
    home_dir = os.getenv("HOME")
    assert home_dir is not None, "HOME needs to be set"
    return home_dir + "/.toggl_track_auth.json"


def read_auth_data() -> Dict[str, str]:
    with open(get_auth_file_name(), "r", encoding="utf-8") as f:
        auth = json.load(f)
    assert (('email' in auth and 'password' in auth) or 'api_token' in auth)
    return auth


def _update_auth(old_auth: Dict[str, str], client_auth: Auth, save=True) \
        -> Dict[str, str]:
    new_auth = dict(old_auth)
    if client_auth.email is not None or 'email' not in new_auth:
        new_auth['email'] = client_auth.email
    if client_auth.password is not None or 'password' not in new_auth:
        new_auth['password'] = client_auth.password
    if client_auth.api_token is not None or 'api_token' not in new_auth:
        new_auth['api_token'] = client_auth.api_token
    if save and new_auth != old_auth:
        with open(get_auth_file_name(), "w", encoding="utf-8") as f:
            json.dump(new_auth, f)
    return new_auth


def create_client(auth=None, allow_user_input=True, reauth_and_save=True):
    if auth is None:
        auth = read_auth_data()
    auth = collections.defaultdict(lambda: None, auth)
    client = TogglTrack(email=auth['email'],
                        password=auth['password'],
                        api_token=auth['api_token'])
    if reauth_and_save:
        updated = client.authenticate(allow_user_input=allow_user_input)
        if updated is not None:
            auth = _update_auth(auth, updated, save=True)
    return client


# ===== helpers for getting objects by ID or name =====


def get_workspace(key, tt=None, verbosity=0) -> Workspace:
    if tt is None:
        tt = create_client()
    ws, verbosity_threshold, extra_msg = None, 2, ''
    if ws is None and key is None:
        ws = tt.workspace()
    try:
        if ws is None and re.search(r'^\d+$', key):
            ws = tt.workspace(workspace_id=int(key))
    except requests.exceptions.HTTPError:
        pass
    if ws is None:
        verbosity_threshold, extra_msg = 1, '*by name*'
        for ww in tt.workspaces():
            if ww.name == key:
                ws = ww
                break
    assert ws is not None, "No workspace found"
    if verbosity >= verbosity_threshold:
        print(f"(tt) Selected workspace '{ws.name}' ({ws.id}){extra_msg}",
              file=sys.stderr)
    return ws


# ===== ad hoc tests =====

# tt = create_client()
# print(tt)
# print(tt.organizations())
# print(tt.workspace_id)
# print(tt.workspaces())
# ws = tt.workspace()
# print(ws)
# print(tt.workspace(workspace_id=tt.workspace_id))
# print(tt.workspace(workspace_id=tt.workspace_id*101))
# prj = ws.projects()
# print(prj)
# print(ws.project(project_id=prj[0].id))
# print(ws.project(project_id=prj[0].id*101))
# cl = ws.clients()
# print(cl)
# print(ws.client(client_id=cl[0].id))
# print(ws.client(client_id=cl[0].id*11))
# tags = ws.tags()
# print(tags)
# print(ws.tag(tag_id=tags[0].id))
# print(tt.time_entries(...tbd...))
