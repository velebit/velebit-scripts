#!/not-executable/python3
import bs4
import json
import os
import requests
import sys
import urllib.parse
import warnings
from typing import Any, Callable, Collection, Sequence, Mapping, Type, TypeVar

# ===== general helpers =====


def html2text(html: str) -> str:
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore", category=bs4.MarkupResemblesLocatorWarning)
        return bs4.BeautifulSoup(html, features="lxml").get_text("\n\n", strip=True)


def get_from_data_hierarchy(hierarchy: Any, keys: Sequence[str]) -> Any:
    node = hierarchy
    try:
        for key in keys:
            node = node[key]
    except KeyError:
        return None
    except TypeError:
        return None
    except IndexError:
        return None
    return node


def set_in_data_hierarchy(hierarchy: Any, keys: Sequence[str], value: Any) -> None:
    node = hierarchy
    assert len(keys) > 0
    for key in keys[:-1]:
        if key not in node:
            node[key] = {}  # it could be a list, but dict is more likely
        node = node[key]
    node[keys[-1]] = value
    return hierarchy


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

    def __init__(
        self,
        *,
        client_id: str | None = None,
        client_secret: str | None = None,
        refresh_token: str | None = None,
        access_token: str | None = None,
    ):
        self.client_id = client_id
        self.client_secret = client_secret
        self.refresh_token = refresh_token
        self.access_token = access_token

    def __eq__(self, other: Any) -> bool:
        return (
            isinstance(other, Auth)
            and self.client_id == other.client_id
            and self.client_secret == other.client_secret
            and self.refresh_token == other.refresh_token
            and self.access_token == other.access_token
        )

    def clone(self) -> "Auth":
        return self.__class__(**self.__dict__)


# ===== Miro client =====


class Client(object):
    """Client for access to Miro."""

    def __init__(
        self,
        *,
        auth: Auth = Auth(),
        client_id: str | None = None,
        client_secret: str | None = None,
        refresh_token: str | None = None,
        access_token: str | None = None,
        default_verbosity: int = 0,
    ):
        self.__auth = auth
        if client_id is not None:
            self.__auth.client_id = client_id
        if client_secret is not None:
            self.__auth.client_secret = client_secret
        if refresh_token is not None:
            self.__auth.refresh_token = refresh_token
        if access_token is not None:
            self.__auth.access_token = access_token
        self.__default_verbosity = default_verbosity

    def __repr__(self) -> str:
        return f"{type(self).__name__}(...)"

    def __eq__(self, other: Any) -> bool:
        return isinstance(other, Client) and self.__auth == other.__auth

    @property
    def default_verbosity(self) -> int:
        return self.__default_verbosity

    # HTTP request helpers

    @classmethod
    def _make_basic_request(
        cls,
        *,
        request: Callable[..., requests.Response] = requests.post,
        url: str,
        accept_codes: set[int] = {requests.codes.ok},
        extra_headers: dict[str, str] = {},
        verbosity: int = 0,
        **kwargs: Any,
    ) -> requests.Response:
        headers = {"accept": "application/json", **extra_headers}
        response = request(url, headers=headers, **kwargs)
        if response.status_code not in accept_codes:
            verbosity_threshold = 0
            if verbosity >= verbosity_threshold:
                print(
                    f"(M) Unexpected response code {response.status_code} for url: {url}; json: {response.json()!r}",
                    file=sys.stderr,
                )
            # try normal response error mechanism...
            response.raise_for_status()
            # ...otherwise generate our own exception
            raise UnexpectedHTTPResponseError(
                "Unexpected status: {code} {reason} for url: {url}".format(
                    code=response.status_code, reason=response.reason, url=url
                ),
                response=response,
            )
        return response

    def _make_auth_request(
        self,
        *,
        extra_headers: dict[str, str] = {},
        verbosity: int | None = None,
        **kwargs: Any,
    ) -> requests.Response:
        request_verbosity = (
            verbosity if verbosity is not None else self.__default_verbosity
        )
        if self.__auth.access_token is None:
            raise MissingAuthorizationError("Access token not present.")
        headers = {
            "authorization": "Bearer " + self.__auth.access_token,
            **extra_headers,
        }
        return self._make_basic_request(
            extra_headers=headers, verbosity=request_verbosity, **kwargs
        )

    # authentication-related functionality

    @property
    def auth(self) -> Auth:
        return self.__auth.clone()

    def is_access_token_valid(self) -> bool:
        if self.__auth.access_token is None:
            return False
        url = "https://api.miro.com/v1/oauth-token"
        response = self._make_auth_request(
            request=requests.get,
            url=url,
            accept_codes={requests.codes.ok, requests.codes.unauthorized},
            verbosity=-1,
        )
        return response.status_code == requests.codes.ok

    def create_access_token_via_settings(self) -> Auth:
        if self.__auth.client_id is not None:
            print(f"Your app's Client ID:     {self.__auth.client_id}\n")
        while self.__auth.client_id is None:
            print(
                "Enter your app's Client ID.\n"
                "  You can find this in the App Credentials section of the\n"
                "  app's page, accessible from your Dev Team > Profile\n"
                "  settings > Your apps > Created apps > (select the app)."
            )
            value = input("> ").strip()
            if value != "":
                self.__auth.client_id = value
        print(f"Your app's Client secret: {self.__auth.client_secret}\n")
        while self.__auth.client_secret is None:
            print(
                "Enter your app's Client secret.\n"
                "  You can find this in the App Credentials section of the\n"
                "  app's page, accessible from your Dev Team > Profile\n"
                "  settings > Your apps > Created apps > (select the app)."
            )
            value = input("> ").strip()
            if value != "":
                self.__auth.client_secret = value
        self.__auth.access_token = None
        self.__auth.refresh_token = None
        while self.__auth.access_token is None and self.__auth.refresh_token is None:
            print(
                "Enter your Miro app's Access token.\n"
                "  You can generate this from the app's page, accessible\n"
                "  from your Dev Team > Profile settings > Your apps >\n"
                "  Created apps > (select the app). On the app's page,\n"
                "  scroll down to find the 'Install app and get OAuth\n"
                "  token' button, click it, and install the app to the\n"
                "  desired workspace. This will show you the tokens.\n"
                "  You can leave this blank to use the refresh token to\n"
                "  immediately refresh."
            )
            value = input("> ").strip()
            if value != "":
                self.__auth.access_token = value
            print(
                "Enter your Miro app's Refresh token.\n"
                "  You can generate this from the app's page, accessible\n"
                "  from your Dev Team > Profile settings > Your apps >\n"
                "  Created apps > (select the app). On the app's page,\n"
                "  scroll down to find the 'Install app and get OAuth\n"
                "  token' button, click it, and install the app to the\n"
                "  desired workspace. This will show you the tokens.\n"
                "  You can leave this blank to disable refresh."
            )
            value = input("> ").strip()
            if value != "":
                self.__auth.refresh_token = value
        if self.__auth.access_token is None and self.__auth.refresh_token is not None:
            return self.refresh_access_token()
        return self.auth

    def create_access_token(self) -> Auth:
        # TODO: Consider implementing creating the access token by using (and
        # possibly intercepting) the redirect mechanism. But we don't have that
        # yet.
        return self.create_access_token_via_settings()

    def refresh_access_token(self) -> Auth:
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
            "refresh_token": self.__auth.refresh_token,
        }
        data = self._make_basic_request(
            request=requests.post,
            url=url,
            params=params,
            verbosity=self.default_verbosity,
        ).json()
        self.__auth.access_token = data["access_token"]
        self.__auth.refresh_token = data["refresh_token"]
        return self.auth

    def authenticate(self, *, allow_user_input: bool = True) -> Auth | None:
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
            raise RuntimeError(
                "Could not refresh auth token, and could not"
                " get a new one without user input."
            )
        auth = self.create_access_token()
        if self.is_access_token_valid():  # is the check even needed?
            return auth
        raise RuntimeError("Could not get or create valid auth data.")

    # accessing objects

    def boards(self) -> list["Board"]:
        url = "https://api.miro.com/v2/boards"
        params: dict[str, Any] = {
            # TODO?
            "sort": "alphabetically",
            "offset": 0,
            "limit": 20,
        }
        boards: list["Board"] = []
        while True:
            response = self._make_auth_request(
                request=requests.get, url=url, params=params
            )
            json = response.json()
            for board_data in json["data"]:
                boards.append(
                    Board._from_json(  # pyright: ignore[reportPrivateUsage]
                        board_data, client=self
                    )
                )
            if json["offset"] + json["size"] >= json["total"]:
                break
            params["offset"] = json["offset"] + json["size"]
        return boards

    def board_by_id(self, id: str) -> "Board | None":
        url = "https://api.miro.com/v2/boards/" + urllib.parse.quote(id)
        try:
            response = self._make_auth_request(request=requests.get, url=url)
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == requests.codes.not_found:
                return None
            else:
                raise
        return Board._from_json(  # pyright: ignore[reportPrivateUsage]
            response.json(), client=self
        )

    def board_by_name(self, name: str) -> "Board | None":
        for b in self.boards():
            if b.name == name:
                return b
        return None


# ===== Miro board =====


ItemT = TypeVar("ItemT", bound="Item")


class Board(object):
    """A board in Miro."""

    def __init__(self, *, id: str, name: str, client: Client | None = None):
        self.__id = id
        self.__name = name
        self.__client = client

    def __repr__(self) -> str:
        return f"{type(self).__name__}(id={self.id!r}, name={self.name!r})"

    def __eq__(self, other: Any) -> bool:
        return isinstance(other, Board) and self.__id == other.__id

    @classmethod
    def _from_json(cls, json: dict[str, Any], client: Client | None = None) -> "Board":
        assert json["type"] == "board"
        return cls(id=json["id"], name=json["name"], client=client)

    @property
    def id(self) -> str:
        return self.__id

    @property
    def name(self) -> str:
        return self.__name

    @property
    def client(self) -> Client | None:
        return self.__client

    def items(
        self,
        item_class: type[ItemT],
        *,
        parent_item_id: str | None = None,
    ) -> list[ItemT]:
        if item_class is Item:
            item_type = None
        else:
            item_type = item_class.json_type()

        url = "https://api.miro.com/v2/boards/" + urllib.parse.quote(self.id) + "/items"
        params: dict[str, Any] = {"limit": 20}
        if item_type is not None:
            params["type"] = item_type
        if parent_item_id is not None:
            params["parent_item_id"] = parent_item_id
        items: list[ItemT] = []
        item_ids: set[str] = set()
        # In late May and early June 2025, the 'data' element in the JSON item
        # list sometimes contained garbage (e.g. wrong colors). I added this
        # code to see whether getting it via the item ID would help... which it
        # didn't, so this was never enabled except for that test. In any case,
        # it works correctly again.
        force_item_fetch = False
        while True:
            assert self.client is not None
            response = (
                self.client._make_auth_request(  # pyright: ignore[reportPrivateUsage]
                    request=requests.get, url=url, params=params
                )
            )
            json = response.json()
            for item_data in json["data"]:
                assert item_type is None or item_data["type"] == item_type
                if item_data["id"] not in item_ids:
                    if force_item_fetch:
                        item = item_class.by_id(
                            id=item_data["id"],
                            board=self,
                            compare_with_json=item_data,
                        )
                    else:
                        item = item_class._from_json(  # pyright: ignore[reportPrivateUsage]
                            json=item_data, board=self
                        )
                    assert isinstance(item, item_class)
                    if item_type is not None:
                        assert (
                            item.type == item_type
                        ), f"type mismatch: expected {item_type}, got {item.type}"
                    assert item.id is not None
                    items.append(item)
                    item_ids.add(item.id)
            if "cursor" not in json:
                break
            params["cursor"] = json["cursor"]
        return items

    def frames(self, parent_item_id: str | None = None) -> list["Frame"]:
        return self.items(Frame, parent_item_id=parent_item_id)

    def sticky_notes(self, parent_item_id: str | None = None) -> list["StickyNote"]:
        return self.items(StickyNote, parent_item_id=parent_item_id)

    def item_by_id(
        self,
        item_id: str,
        *,
        subdir: str = "items",
        expected_type: str | None = None,
        compare_with_json: dict[str, Any] | None = None,
    ) -> "Item":
        url = (
            "https://api.miro.com/v2/boards/"
            + urllib.parse.quote(self.id)
            + "/"
            + subdir
            + "/"
            + urllib.parse.quote(item_id)
        )
        assert self.client is not None
        try:
            response = (
                self.client._make_auth_request(  # pyright: ignore[reportPrivateUsage]
                    request=requests.get, url=url
                )
            )
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == requests.codes.not_found:
                raise KeyError(
                    f"No item found with id '{item_id}' on board '{self.id}'"
                )
            else:
                raise
        json = response.json()
        if expected_type is not None and json["type"] != expected_type:
            ext_id = subdir + "/" + urllib.parse.quote(item_id)
            raise ValueError(
                f"Expected type '{expected_type}', got"
                f" '{json['type']}' for item .../{ext_id}"
            )
        if compare_with_json is not None:
            # compare_with_json ignores verbosity
            if json == compare_with_json:
                print(f"(M) New JSON for {item_id} matches old", file=sys.stderr)
            else:
                print(
                    f"(M) New JSON for {item_id} DOESN'T match old:\n"
                    f"--- old ---\n{compare_with_json}\n"
                    f"--- new ---\n{json}\n--- --- ---",
                    file=sys.stderr,
                )
        return Item._from_json(json, board=self)  # pyright: ignore[reportPrivateUsage]

    def item_by_type_and_id(
        self,
        item_type: str,
        item_id: str,
        *,
        compare_with_json: dict[str, Any] | None = None,
    ) -> "Item":
        subclass = Item._get_subclass(item_type)  # pyright: ignore[reportPrivateUsage]
        assert subclass is not None
        item = subclass.by_id(
            id=item_id, board=self, compare_with_json=compare_with_json
        )
        assert item.type == item_type
        return item

    def groups(self) -> list["Group"]:
        url = (
            "https://api.miro.com/v2/boards/" + urllib.parse.quote(self.id) + "/groups"
        )
        params: dict[str, Any] = {"limit": 20}
        items: list["Group"] = []
        item_ids: set[str] = set()
        # The 'data' element in the JSON returned by the groups query is
        # suspect; for example, the items list may be incomplete. (Last checked
        # 2025-06-15.) We force re-fetching each group by ID, instead.
        force_group_fetch = True
        while True:
            assert self.client is not None
            response = (
                self.client._make_auth_request(  # pyright: ignore[reportPrivateUsage]
                    request=requests.get, url=url, params=params
                )
            )
            json = response.json()
            for group_data in json["data"]:
                if group_data["id"] not in item_ids:
                    if force_group_fetch:
                        item = Group.by_id(group_data["id"], board=self)
                        # To check whether the groups query is still bad, add:
                        #             compare_with_json=group_data))
                    else:
                        item = Group._from_json(  # pyright: ignore[reportPrivateUsage]
                            group_data, board=self
                        )
                    assert item.id is not None
                    items.append(item)
                    item_ids.add(item.id)
            if "cursor" not in json:
                break
            params["cursor"] = json["cursor"]
        return items


# ===== Items on a Miro board =====


class Item(object):
    """An item from a Miro board."""

    __classes: dict[str, Type["Item"]] = dict()

    def __init__(self, *, json: dict[str, Any], board: Board | None = None):
        self.__json = json
        self.__board = board

    def __repr__(self) -> str:
        cln = type(self).__name__
        if cln == "Item":
            return f"{cln}(type={self.type!r}, id={self.id!r}, ...)"
        else:
            return f"{cln}(id={self.id!r}, ...)"

    def __eq__(self, other: Any) -> bool:
        return (
            isinstance(other, Item)
            and self.type == other.type
            and self.board is not None
            and self.board == other.board
            and self.id == other.id
        )

    @classmethod
    def _from_json(
        cls: type[ItemT], json: dict[str, Any], board: Board | None = None
    ) -> ItemT:
        assert "type" in json
        subclass = cls._get_subclass(json["type"], fallback=Item)
        assert subclass is not None
        assert issubclass(subclass, cls)
        return subclass(json=json, board=board)

    @classmethod
    def _register_subclass(cls) -> dict[str, Type["Item"]]:
        assert cls.json_type() not in cls.__classes
        cls.__classes[cls.json_type()] = cls
        return cls.__classes

    @classmethod
    def _get_subclass(
        cls, item_type: str, fallback: Type["Item"] | None = None
    ) -> Type["Item"] | None:
        return cls.__classes.get(item_type, fallback)

    @classmethod
    def by_id(
        cls: type[ItemT],
        id: str,
        *,
        board: Board,
        compare_with_json: dict[str, Any] | None = None,
    ) -> ItemT:
        item = board.item_by_id(
            id,
            subdir=cls.request_subdir(),
            expected_type=cls.json_type(),
            compare_with_json=compare_with_json,
        )
        assert type(item) is cls, f"Expected {cls}, got {type(item)}"
        return item

    @property
    def json(self) -> dict[str, Any]:
        return self.__json

    @property
    def board(self) -> Board | None:
        return self.__board

    def _get_property(self, *keys: str) -> Any:
        return get_from_data_hierarchy(self.json, keys)

    def _update_property_fields(
        self,
        keys: Sequence[str],
        values: Mapping[str, Any],
        request_values: Mapping[str, Any] | None = None,
        verbosity: int | None = None,
    ) -> None:
        def limit_keys(
            mapping: Mapping[str, Any], keys: Collection[str]
        ) -> dict[str, Any]:
            return {k: mapping[k] for k in keys if k in mapping}

        assert self.board is not None and self.board.client is not None
        if request_values is None:
            request_values = values
        if verbosity is None:
            verbosity = self.board.client.default_verbosity
        verbosity_threshold = 1
        old_values = limit_keys(get_from_data_hierarchy(self.json, keys), values.keys())
        if old_values == values:
            if verbosity >= verbosity_threshold:
                print(
                    f"(M) No need to update {'.'.join(keys)} to {values} for item {self.id}",
                    file=sys.stderr,
                )
            return
        subdir = self.request_subdir()
        url = (
            "https://api.miro.com/v2/boards/"
            + urllib.parse.quote(self.board.id)
            + "/"
            + subdir
            + "/"
            + urllib.parse.quote(self.id)
        )
        request_hierarchy: dict[str, Any] = {}
        set_in_data_hierarchy(request_hierarchy, keys, request_values)
        response = (
            self.board.client._make_auth_request(  # pyright: ignore[reportPrivateUsage]
                request=requests.patch, url=url, json=request_hierarchy
            )
        )
        new_json: dict[str, Any] = response.json()
        assert (
            new_json["type"] == self.type
        ), f"Type changed after update: expected {self.type}, got {new_json['type']}"
        self.__json = new_json
        if verbosity >= verbosity_threshold:
            new_values = limit_keys(
                get_from_data_hierarchy(new_json, keys), values.keys()
            )
            patch_verbosity_threshold = 2
            patch_text = (
                f"PATCH response: {response.status_code} {response.reason}"
                if verbosity >= patch_verbosity_threshold
                else ""
            )
            if new_values == values:
                print(
                    f"(M) Updated {'.'.join(keys)} to {new_values} for item {self.id}"
                    f"{', ' if patch_text else ''}{patch_text}",
                    file=sys.stderr,
                )
            elif new_values == old_values:
                print(
                    f"(M) Failed to update {'.'.join(keys)} to {values} for item {self.id},"
                    f" value is still {new_values}{' after ' if patch_text else ''}{patch_text}",
                    file=sys.stderr,
                )
            else:
                print(
                    f"(M) Updated {'.'.join(keys)} to {new_values} for item {self.id},"
                    f" but expected {values}{'; ' if patch_text else ''}{patch_text}",
                    file=sys.stderr,
                )

    @property
    def id(self) -> str:
        id = self._get_property("id")
        assert id is not None, f"Item {self!r} has no id"
        return id

    @property
    def type(self) -> str:
        type = self._get_property("type")
        assert type is not None, f"Item {self!r} has no type"
        return type

    @property
    def link(self) -> str | None:
        return self._get_property("links", "self")

    @property
    def parent_id(self) -> str | None:
        return self._get_property("parent", "id")

    @property
    def parent(self) -> "Item | None":
        parent_id = self.parent_id
        if parent_id is None:
            return None
        else:
            assert self.board is not None
            return self.board.item_by_id(parent_id)

    @property
    def fill_color(self) -> str | None:
        return self._get_property("style", "fillColor")

    @property
    def size(self) -> tuple[float, float] | None:
        geometry = self._get_property("geometry")
        if geometry is None:
            return None
        return (geometry["width"], geometry["height"])

    def set_size(self, size: tuple[float, float]) -> None:
        # Note: for fixed aspect ratio items, we should be setting only one of width and height.
        # TODO: Figure out which items aren't fixed aspect ratio.
        # Note: as of 2026-02-22, setting the size DOES NOT work, at least for sticky notes.
        self._update_property_fields(
            ["geometry"],
            {"width": size[0], "height": size[1]},
            request_values={"width": size[0]},
            # request_values={"height": size[1]},
        )

    @property
    def relative_position_anchor(self) -> str | None:
        position = self._get_property("position")
        if position is None:
            return None
        if (
            position["relativeTo"] == "parent_top_left"
            and position["origin"] == "center"
        ):
            return self.parent_id
        elif (
            position["relativeTo"] == "canvas_center" and position["origin"] == "center"
        ):
            return None  # global as relative
        return None

    @property
    def relative_position(self) -> tuple[float, float] | None:
        # TODO: Add absolute_position too?
        position = self._get_property("position")
        if position is None:
            return None
        return (position["x"], position["y"])

    def set_relative_position(self, position: tuple[float, float]) -> None:
        self._update_property_fields(["position"], {"x": position[0], "y": position[1]})

    @staticmethod  # there's no @staticproperty!
    def json_type() -> str:
        raise NotImplementedError(
            "json_type() needs to be implemented by subclasses of Item"
        )

    @staticmethod  # there's no @staticproperty!
    def request_subdir() -> str:
        raise NotImplementedError(
            "request_subdir() needs to be implemented by subclasses of Item"
        )


class Frame(Item):
    """A frame item from a Miro board."""

    def __repr__(self) -> str:
        cln = type(self).__name__
        return f"{cln}(id={self.id!r}, text={self.text!r}, ...)"

    @staticmethod  # there's no @staticproperty!
    def json_type() -> str:
        return "frame"

    @staticmethod  # there's no @staticproperty!
    def request_subdir() -> str:
        return "frames"

    @property
    def text(self) -> str | None:
        return self._get_property("data", "title")

    def items(self, item_class: type[ItemT]) -> list[ItemT]:
        assert self.board is not None
        return self.board.items(item_class, parent_item_id=self.id)

    def sticky_notes(self) -> list["StickyNote"]:
        return self.items(StickyNote)


Frame._register_subclass()  # pyright: ignore[reportPrivateUsage]


class StickyNote(Item):
    """A sticky_note item from a Miro board."""

    def __repr__(self) -> str:
        cln = type(self).__name__
        return f"{cln}(id={self.id!r}, text={self.text!r}, ...)"

    @staticmethod  # there's no @staticproperty!
    def json_type() -> str:
        return "sticky_note"

    @staticmethod  # there's no @staticproperty!
    def request_subdir() -> str:
        return "sticky_notes"

    @property
    def text(self) -> str:
        return html2text(self._get_property("data", "content"))


StickyNote._register_subclass()  # pyright: ignore[reportPrivateUsage]


class Shape(Item):
    """A shape item from a Miro board."""

    def __repr__(self) -> str:
        cln = type(self).__name__
        return f"{cln}(id={self.id!r}, shape={self.shape!r}, text={self.text!r}, ...)"

    @staticmethod  # there's no @staticproperty!
    def json_type() -> str:
        return "shape"

    @staticmethod  # there's no @staticproperty!
    def request_subdir() -> str:
        return "shapes"

    @property
    def text(self) -> str:
        return html2text(self._get_property("data", "content"))

    @property
    def shape(self) -> str | None:
        return self._get_property("data", "shape")


Shape._register_subclass()  # pyright: ignore[reportPrivateUsage]


class Text(Item):
    """A text item from a Miro board."""

    def __repr__(self) -> str:
        cln = type(self).__name__
        return f"{cln}(id={self.id!r}, text={self.text!r}, ...)"

    @staticmethod  # there's no @staticproperty!
    def json_type() -> str:
        return "text"

    @staticmethod  # there's no @staticproperty!
    def request_subdir() -> str:
        return "texts"

    @property
    def text(self) -> str:
        return html2text(self._get_property("data", "content"))


Text._register_subclass()  # pyright: ignore[reportPrivateUsage]


class Group(Item):
    """A group from a Miro board."""

    @staticmethod  # there's no @staticproperty!
    def json_type() -> str:
        return "group"

    @staticmethod  # there's no @staticproperty!
    def request_subdir() -> str:
        return "groups"

    @property
    def item_ids(self) -> list[str] | None:
        return self._get_property("data", "items")

    @property
    def items(self) -> list[Item]:
        assert self.board is not None
        assert self.item_ids is not None
        return [self.board.item_by_id(str(i)) for i in self.item_ids]

    @property
    def relative_position(self) -> None:
        return None

    def set_relative_position(self, position: tuple[float, float]) -> None:
        raise NotImplementedError(
            "Groups cannot be moved directly. Move the group's items instead."
        )

    def get_items_recursive(self) -> list[Item]:
        """Recursively get all non-Group items in this group."""
        all_items: list[Item] = []
        for item in self.items:
            if isinstance(item, Group):
                all_items.extend(item.get_items_recursive())
            else:
                all_items.append(item)
        return all_items


Group._register_subclass()  # pyright: ignore[reportPrivateUsage]


# ===== managing saved authentication and the client object =====


def get_auth_file_name() -> str:
    home_dir = os.getenv("HOME")
    assert home_dir is not None, "HOME needs to be set"
    return home_dir + "/.config/bert_miro/auth.json"


def read_auth_data() -> dict[str, Any]:
    with open(get_auth_file_name(), "r", encoding="utf-8") as f:
        auth = json.load(f)
    assert "app_name" in auth
    assert "client_id" in auth
    assert "client_secret" in auth
    return auth


def _update_auth(
    old_auth: dict[str, Any], client_auth: Auth, save: bool = True
) -> dict[str, Any]:
    new_auth = dict(old_auth)
    new_auth["access_token"] = client_auth.access_token
    new_auth["refresh_token"] = client_auth.refresh_token
    if save and new_auth != old_auth:
        with open(get_auth_file_name(), "w", encoding="utf-8") as f:
            json.dump(new_auth, f)
    return new_auth


def create_client(
    auth: dict[str, Any] | None = None,
    allow_user_input: bool = True,
    reauth_and_save: bool = True,
    default_verbosity: int = 0,
) -> Client:
    if auth is None:
        auth = read_auth_data()
    client = Client(
        client_id=auth.get("client_id", None),
        client_secret=auth.get("client_secret", None),
        refresh_token=auth.get("refresh_token", None),
        access_token=auth.get("access_token", None),
        default_verbosity=default_verbosity,
    )
    if reauth_and_save:
        updated = client.authenticate(allow_user_input=allow_user_input)
        if updated is not None:
            auth = _update_auth(auth, updated, save=True)
    return client


# ===== getting a board/frame handle, with auth setup and logging =====


def get_board(
    board_id: str,
    board_name: str,
    auth: dict[str, Any] | None = None,
    verbosity: int = 0,
) -> Board:
    verbosity_threshold, extra_msg = 2, ""
    client = create_client(
        auth=auth, reauth_and_save=False, default_verbosity=verbosity
    )
    try:
        board = client.board_by_id(board_id)
    except requests.exceptions.HTTPError as e:
        if e.response.status_code != requests.codes.unauthorized:
            raise
        # authentication has failed, so reauthenticate
        client = create_client(
            auth=auth, reauth_and_save=True, default_verbosity=verbosity
        )
        board = client.board_by_id(board_id)
    if board is None:
        board = client.board_by_name(board_name)
        if board_name != board_id:
            verbosity_threshold, extra_msg = 1, "*by name*, fix the ID!"
    assert board is not None, "No open board found"
    if verbosity >= verbosity_threshold:
        print(
            f"(M) Selected board '{board.name}' ({board.id}){extra_msg}",
            file=sys.stderr,
        )
    return board


def get_frame(
    board: Board, frame_id: str, frame_name: str, verbosity: int = 0
) -> Frame:
    verbosity_threshold, extra_msg = 1, ""
    try:
        frame = Frame.by_id(frame_id, board=board)
    except (KeyError, requests.exceptions.HTTPError):
        raise  # getting by name is unimplemented
        # ... verbosity_threshold, extra_msg = 0, '*by name*, fix the ID!'
    assert type(frame) is Frame, f"Bad type for frame: {type(frame)}"
    if verbosity >= verbosity_threshold:
        print(
            f"(M) Selected frame '{frame.text}' ({frame.id}){extra_msg}",
            file=sys.stderr,
        )
    return frame


def create_item_id_to_group_mapping(board: Board) -> dict[str, Group]:
    mapping: dict[str, Group] = {}
    for group in board.groups():
        for item_id in group.item_ids or []:
            assert item_id not in mapping  # Miro invariant
            mapping[item_id] = group
    return mapping


# ... ad hoc tests ...

# client = create_client()
# print(client)
# print(client.boards())
# print(client.board_by_id("uXjVPdpN6Vw="))
# print(client.board_by_id("ajshjaljs"))
# print(client.board_by_name("Dvorniki tasks"))
# print(client.board_by_name("ajshjaljs"))
# board = client.board_by_id("uXjVPdpN6Vw=")
# print(board.items(Item))
# print(board.frames())
# print(board.sticky_notes()[0].json)
# print(board.items(Shape)[0].json)
# print(board.items(Text)[0].json)

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
