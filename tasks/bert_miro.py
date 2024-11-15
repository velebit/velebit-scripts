#!/not-executable/python3
import bs4
import json
import os
import requests
import sys
import urllib.parse
import warnings


# ===== general helpers =====

def html2text(html):
    with warnings.catch_warnings():
        warnings.filterwarnings('ignore',
                                category=bs4.MarkupResemblesLocatorWarning)
        return bs4.BeautifulSoup(html, features="lxml").get_text(
            "\n\n", strip=True)


# ===== HTTP request error classes =====

class UnexpectedHTTPResponseError(requests.exceptions.HTTPError):
    """The HTTP response code which was received was unexpected."""


class ClientStateError(requests.exceptions.RequestException):
    """Some error in the state management of the Client has occurred.
    Ideally the specific error will be represented as a derived class."""


class MissingAuthorizationError(ClientStateError):
    """The authorization information needed to make a request was missing.
    Note that different requests have different authorization needs,
    so while some of the information may be specified, what we needed
    right now wasn't."""


# ===== Miro client authentication data =====

class Auth(object):

    def __init__(self, *, client_id=None, client_secret=None,
                 refresh_token=None, access_token=None):
        self.client_id = client_id
        self.client_secret = client_secret
        self.refresh_token = refresh_token
        self.access_token = access_token

    def __eq__(self, other):
        return (isinstance(self, Auth) and isinstance(other, Auth) and
                self.client_id == other.client_id and
                self.client_secret == other.client_secret and
                self.refresh_token == other.refresh_token and
                self.access_token == other.access_token)

    def clone(self):
        return self.__class__(**self.__dict__)


# ===== Miro client =====

class Client(object):
    """Client for access to Miro."""

    def __init__(self, *, auth=Auth(), client_id=None, client_secret=None,
                 refresh_token=None, access_token=None):
        self.__auth = auth
        if client_id is not None:
            self.__auth.client_id = client_id
        if client_secret is not None:
            self.__auth.client_secret = client_secret
        if refresh_token is not None:
            self.__auth.refresh_token = refresh_token
        if access_token is not None:
            self.__auth.access_token = access_token

    def __repr__(self):
        return f"{type(self).__name__}(...)"

    def __eq__(self, other):
        return (isinstance(self, Client) and isinstance(other, Client) and
                self.__auth == other.__auth)

    # HTTP request helpers

    @classmethod
    def _make_basic_request(cls, *, request=requests.post, url,
                            accept_codes={requests.codes.ok},
                            extra_headers={}, **kwargs):
        headers = {
            "accept": "application/json",
            **extra_headers
        }
        response = request(url, headers=headers, **kwargs)
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

    def _make_auth_request(self, *, extra_headers={}, **kwargs):
        if self.__auth.access_token is None:
            raise MissingAuthorizationError("Access token not present.")
        headers = {
            "authorization": "Bearer " + self.__auth.access_token,
            **extra_headers
        }
        return self._make_basic_request(extra_headers=headers, **kwargs)

    # authentication-related functionality

    @property
    def auth(self):
        return self.__auth.clone()

    def is_access_token_valid(self):
        if self.__auth.access_token is None:
            return False
        url = "https://api.miro.com/v1/oauth-token"
        response = self._make_auth_request(
            request=requests.get, url=url,
            accept_codes={requests.codes.ok,
                          requests.codes.unauthorized})
        return response.status_code == requests.codes.ok

    def create_access_token_via_settings(self):
        if self.__auth.client_id is not None:
            print(f"Your app's Client ID:     {self.__auth.client_id}\n")
        while self.__auth.client_id is None:
            print("Enter your app's Client ID.\n"
                  "  You can find this in the App Credentials section of the\n"
                  "  app's page, accessible from your Dev Team > Profile\n"
                  "  settings > Your apps > Created apps > (select the app).")
            value = input("> ").strip()
            if value != "":
                self.__auth.client_id = value
        if self.__auth.client_id is not None:
            print(f"Your app's Client secret: {self.__auth.client_secret}\n")
        while self.__auth.client_secret is None:
            print("Enter your app's Client secret.\n"
                  "  You can find this in the App Credentials section of the\n"
                  "  app's page, accessible from your Dev Team > Profile\n"
                  "  settings > Your apps > Created apps > (select the app).")
            value = input("> ").strip()
            if value != "":
                self.__auth.client_secret = value
        self.__auth.access_token = None
        self.__auth.refresh_token = None
        while (self.__auth.access_token is None
                and self.__auth.refresh_token is None):
            print("Enter your Miro app's Access token.\n"
                  "  You can generate this from the app's page, accessible\n"
                  "  from your Dev Team > Profile settings > Your apps >\n"
                  "  Created apps > (select the app). On the app's page,\n"
                  "  scroll down to find the 'Install app and get OAuth\n"
                  "  token' button, click it, and install the app to the\n"
                  "  desired workspace. This will show you the tokens.\n"
                  "  You can leave this blank to use the refresh token to\n"
                  "  immediately refresh.")
            value = input("> ").strip()
            if value != "":
                self.__auth.access_token = value
            print("Enter your Miro app's Refresh token.\n"
                  "  You can generate this from the app's page, accessible\n"
                  "  from your Dev Team > Profile settings > Your apps >\n"
                  "  Created apps > (select the app). On the app's page,\n"
                  "  scroll down to find the 'Install app and get OAuth\n"
                  "  token' button, click it, and install the app to the\n"
                  "  desired workspace. This will show you the tokens.\n"
                  "  You can leave this blank to disable refresh.")
            value = input("> ").strip()
            if value != "":
                self.__auth.refresh_token = value
        if (self.__auth.access_token is None
                and self.__auth.refresh_token is not None):
            return self.refresh_access_token()
        return self.auth

    def create_access_token(self):
        # TODO: Consider implementing creating the access token by using (and
        # possibly intercepting) the redirect mechanism. But we don't have that
        # yet.
        return self.create_access_token_via_settings()

    def refresh_access_token(self):
        if self.__auth.client_id is None:
            raise MissingAuthorizationError("Client ID not known.")
        if self.__auth.client_secret is None:
            raise MissingAuthorizationError("Client secret not known.")
        if self.__auth.refresh_token is None:
            raise MissingAuthorizationError("Refresh token not known.")
        url = "https://api.miro.com/v1/oauth/token"
        params = {
            "grant_type": "refresh_token",
            "client_id": self.__auth.client_id,
            "client_secret": self.__auth.client_secret,
            "refresh_token": self.__auth.refresh_token
        }
        data = self._make_basic_request(
            request=requests.post, url=url, params=params).json()
        self.__auth.access_token = data['access_token']
        self.__auth.refresh_token = data['refresh_token']
        return self.auth

    def authenticate(self, *, allow_user_input=True):
        if self.is_access_token_valid():
            return None
        try:
            auth = self.refresh_access_token()
            if self.is_access_token_valid():  # is the check even needed?
                return auth
        except MissingAuthorizationError:
            pass
        except requests.exceptions.HTTPError:
            pass
        if not allow_user_input:
            raise RuntimeError("Could not refresh auth token, and could not"
                               " get a new one without user input.")
        auth = self.create_access_token()
        if self.is_access_token_valid():  # is the check even needed?
            return auth
        raise RuntimeError("Could not get or create valid auth data.")

    # accessing objects

    def boards(self):
        url = "https://api.miro.com/v2/boards"
        params = {
            "sort": "alphabetically",
            "offset": 0,
            "limit": 20
        }
        boards = []
        while True:
            response = self._make_auth_request(request=requests.get, url=url,
                                               params=params)
            json = response.json()
            for board_data in json['data']:
                boards.append(Board._from_json(board_data, client=self))
            if json['offset'] + json['size'] >= json['total']:
                break
            params['offset'] = json['offset'] + json['size']
        return boards

    def board_by_id(self, id):
        url = "https://api.miro.com/v2/boards/" + urllib.parse.quote(id)
        try:
            response = self._make_auth_request(request=requests.get, url=url)
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == requests.codes.not_found:
                return None
            else:
                raise
        return Board._from_json(response.json(), client=self)

    def board_by_name(self, name):
        for b in self.boards():
            if b.name == name:
                return b
        return None


# ===== Miro board =====

class Board(object):
    """A board in Miro."""

    def __init__(self, *, id, name, client=None):
        self.__id = id
        self.__name = name
        self.__client = client

    def __repr__(self):
        return f"{type(self).__name__}(id={self.id!r}, name={self.name!r})"

    def __eq__(self, other):
        return (isinstance(self, Board) and isinstance(other, Board) and
                self.__id is not None and
                self.__id == other.__id)

    @classmethod
    def _from_json(cls, json, client=None):
        assert json['type'] == 'board'
        return cls(id=json['id'], name=json['name'], client=client)

    @property
    def id(self):
        return self.__id

    @property
    def name(self):
        return self.__name

    @property
    def client(self):
        return self.__client

    def items(self, item_type=None, parent_item_id=None):
        url = ("https://api.miro.com/v2/boards/" + urllib.parse.quote(self.id)
               + "/items")
        params = {
            "limit": 20
        }
        if item_type is not None:
            params['type'] = item_type
        if parent_item_id is not None:
            params['parent_item_id'] = parent_item_id
        items = []
        while True:
            response = self.client._make_auth_request(request=requests.get,
                                                      url=url,
                                                      params=params)
            json = response.json()
            for board_data in json['data']:
                items.append(Item._from_json(board_data, board=self))
            if 'cursor' not in json:
                break
            params['cursor'] = json['cursor']
        if item_type is not None:
            assert all([i.type == item_type for i in items])
        return items

    def frames(self, parent_item_id=None):
        return self.items(item_type='frame',
                          parent_item_id=parent_item_id)

    def sticky_notes(self, parent_item_id=None):
        return self.items(item_type='sticky_note',
                          parent_item_id=parent_item_id)

    def item_by_id(self, item_id):
        url = ("https://api.miro.com/v2/boards/" + urllib.parse.quote(self.id)
               + "/items/" + urllib.parse.quote(item_id))
        response = self.client._make_auth_request(request=requests.get,
                                                  url=url)
        return Item._from_json(response.json(), board=self)


# ===== Items on a Miro board =====

class Item(object):
    """An item from a Miro board."""

    __classes = dict()

    def __init__(self, *, json, board=None):
        self.__json = json
        self.__board = board

    def __repr__(self):
        cln = type(self).__name__
        if cln == "Item":
            return f"{cln}(type={self.type!r}, id={self.id!r}, ...)"
        else:
            return f"{cln}(id={self.id!r}, ...)"

    def __eq__(self, other):
        return (isinstance(self, Item) and isinstance(other, Item) and
                self.type is not None and
                self.type == other.type and
                self.board is not None and
                self.board == other.board and
                self.id is not None and
                self.id == other.id)

    @classmethod
    def _from_json(cls, json, board=None):
        assert 'type' in json
        subclass = cls.__classes.get(json['type'], cls)
        return subclass(json=json, board=board)

    @classmethod
    def _register_subclass(cls, json_type):
        assert json_type not in cls.__classes
        cls.__classes[json_type] = cls
        return cls.__classes

    @property
    def _json(self):
        return self.__json

    @property
    def board(self):
        return self.__board

    def _get_property(self, *keys):
        try:
            node = self._json
            for key in keys:
                node = node[key]
            return node
        except KeyError:
            return None
        except TypeError:
            return None
        except IndexError:
            return None

    @property
    def id(self):
        return self._get_property('id')

    @property
    def type(self):
        return self._get_property('type')

    @property
    def link(self):
        return self._get_property('links', 'self')

    @property
    def parent_id(self):
        return self._get_property('parent', 'id')

    @property
    def parent(self):
        parent_id = self.parent_id
        if parent_id is None:
            return None
        else:
            return self.board.item_by_id(parent_id)

    @property
    def fill_color(self):
        return self._get_property('style', 'fillColor')

    @property
    def size(self):
        geometry = self._get_property('geometry')
        if geometry is None:
            return None
        return (geometry['width'], geometry['height'])

    @property
    def relative_position(self):
        # TODO: Add absolute_position too?
        position = self._get_property('position')
        if position is None:
            return None
        if (position['relativeTo'] == 'parent_top_left'
                and position['origin'] == 'center'):
            return (self.parent_id, position['x'], position['y'])
        if (position['relativeTo'] == 'canvas_center'
                and position['origin'] == 'center'):
            return (None, position['x'], position['y'])  # allow global as rel.
        return None


class Frame(Item):
    """A frame item from a Miro board."""

    @property
    def text(self):
        return self._get_property('data', 'title')

    def items(self, item_type=None):
        return self.board.items(item_type=item_type, parent_item_id=self.id)

    def sticky_notes(self):
        return self.items(item_type='sticky_note')


Frame._register_subclass('frame')


class StickyNote(Item):
    """A sticky_note item from a Miro board."""

    @property
    def text(self):
        return html2text(self._get_property('data', 'content'))


StickyNote._register_subclass('sticky_note')


class Shape(Item):
    """A shape item from a Miro board."""

    @property
    def text(self):
        return html2text(self._get_property('data', 'content'))

    @property
    def shape(self):
        return self._get_property('data', 'shape')


Shape._register_subclass('shape')


class Text(Item):
    """A text item from a Miro board."""

    @property
    def text(self):
        return html2text(self._get_property('data', 'content'))


Text._register_subclass('text')


# ===== managing saved authentication and the client object =====

def get_auth_file_name():
    home_dir = os.getenv("HOME")
    assert home_dir is not None, "HOME needs to be set"
    return home_dir + "/.config/bert_miro/auth.json"


def read_auth_data():
    with open(get_auth_file_name(), "r", encoding="utf-8") as f:
        auth = json.load(f)
    assert 'app_name' in auth
    assert 'client_id' in auth
    assert 'client_secret' in auth
    return auth


def _update_auth(old_auth, client_auth, save=True):
    new_auth = dict(old_auth)
    new_auth['access_token'] = client_auth.access_token
    new_auth['refresh_token'] = client_auth.refresh_token
    if save and new_auth != old_auth:
        with open(get_auth_file_name(), "w", encoding="utf-8") as f:
            json.dump(new_auth, f)
    return new_auth


def create_client(auth=None, allow_user_input=True, reauth_and_save=True):
    if auth is None:
        auth = read_auth_data()
    client = Client(client_id=auth.get('client_id', None),
                    client_secret=auth.get('client_secret', None),
                    refresh_token=auth.get('refresh_token', None),
                    access_token=auth.get('access_token', None))
    if reauth_and_save:
        updated = client.authenticate(allow_user_input=allow_user_input)
        if updated is not None:
            auth = _update_auth(auth, updated, save=True)
    return client


# ===== getting a board/frame handle, with auth setup and logging =====

def get_board(board_id, board_name, auth=None, verbosity=0):
    verbosity_threshold, extra_msg = 2, ''
    client = create_client(auth=auth, reauth_and_save=False)
    try:
        board = client.board_by_id(board_id)
    except requests.exceptions.HTTPError as e:
        if e.response.status_code != requests.codes.unauthorized:
            raise
        # authentication has failed, so reauthenticate
        client = create_client(auth=auth, reauth_and_save=True)
        board = client.board_by_id(board_id)
    if board is None:
        board = client.board_by_name(board_name)
        if board_name != board_id:
            verbosity_threshold, extra_msg = 1, '*by name*, fix the ID!'
    assert board is not None, "No open board found"
    if verbosity >= verbosity_threshold:
        print(f"(M) Selected board '{board.name}' ({board.id}){extra_msg}",
              file=sys.stderr)
    return board


def get_frame(board, frame_id, frame_name, verbosity=0):
    verbosity_threshold, extra_msg = 1, ''
    frame = board.item_by_id(frame_id)
    if frame is None:
        pass  # getting by name is unimplemented
        # ... verbosity_threshold, extra_msg = 0, '*by name*, fix the ID!'
    assert frame is not None, "No frame found"
    assert type(frame) is Frame, "Bad type for frame"
    if verbosity >= verbosity_threshold:
        print(f"(M) Selected frame '{frame.text}' ({frame.id}){extra_msg}",
              file=sys.stderr)
    return frame


# ... ad hoc tests ...

# client = create_client()
# print(client)
# print(client.boards())
# print(client.board_by_id("uXjVPdpN6Vw="))
# print(client.board_by_id("ajshjaljs"))
# print(client.board_by_name("Dvorniki tasks"))
# print(client.board_by_name("ajshjaljs"))
# board = client.board_by_id("uXjVPdpN6Vw=")
# print(board.items())
# print(board.frames())
# print(board.sticky_notes()[0]._json)
# print(board.items(item_type='shape')[0]._json)
# print(board.items(item_type='text')[0]._json)

# import regex
# for s in board.sticky_notes():
#     if s.parent_id is None:
#         print("{0:20} {1}".format('', regex.sub(r'\s+', ' ', s.text)))
#     else:
#         print("{0:20} {1}".format(regex.sub(r'\s+', ' ', s.parent.text),
#                                   regex.sub(r'\s+', ' ', s.text)))

# import regex
# for f in board.frames():
#     frame_name = regex.sub(r'\s+', ' ', f.text)
#     for s in f.sticky_notes():
#         print("{0:20} {1}".format(frame_name,
#                                   regex.sub(r'\s+', ' ', s.text)))
