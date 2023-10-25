#!/not-executable/python3
import enum
import habitipy
import sys


# ===== API-related constants =====

class TaskType(enum.Enum):
    # Note that only some of these may be valid for any given request!
    HABIT = "habit"
    DAILY = "daily"
    TODO = "todo"
    REWARD = "reward"


class TasksType(enum.Enum):
    # Note that only some of these may be valid for any given request!
    HABITS = "habits"
    DAILIES = "dailys"  # The API has a typo, I don't want to deal with it
    TODOS = "todos"
    REWARDS = "rewards"
    COMPLETED_TODOS = "completedTodos"  # only N (currently 30) most recent!


task_to_tasks = {
    TaskType.HABIT: TasksType.HABITS,
    TaskType.DAILY: TasksType.DAILIES,
    TaskType.TODO: TasksType.TODOS,
    TaskType.REWARD: TasksType.REWARDS,
}
tasks_to_task = {ts: t for t, ts in task_to_tasks.items()}


# ===== API object classes =====

# ...


# ===== High level API wrapper =====

class Habitica(object):
    """Higher-level client wrapper for access to Habitica."""

    def __init__(self, *, verbosity=0, conf=None):
        self.__verbosity = verbosity
        if conf is None:
            conf = habitipy.load_conf(habitipy.DEFAULT_CONF)
            assert conf is not None
            if self.__verbosity >= 2:
                print("(H) Configuration loaded from "
                      f"'{habitipy.DEFAULT_CONF}'", file=sys.stderr)
        self.__api = habitipy.api.Habitipy(conf)
        self.__task_cache = {}

    def _clear_caches(self):
        self.__task_cache = {}

    def _get_tasks(self, tstype):
        assert isinstance(tstype, TasksType)
        if tstype.value not in self.__task_cache:
            self.__task_cache[tstype.value] = \
                list(self.__api.tasks.user.get(type=tstype.value))
        return self.__task_cache[tstype.value]

    def get_habits(self):
        return self._get_tasks(TasksType.HABITS)

    def get_dailies(self):
        return self._get_tasks(TasksType.DAILIES)

    def get_todos_active(self):
        return self._get_tasks(TasksType.TODOS)

    def get_todos_completed(self):
        return self._get_tasks(TasksType.COMPLETED_TODOS)

    def get_custom_rewards(self):
        return self._get_tasks(TasksType.REWARDS)

    def add_todo(self, text, notes=None):
        # Optional Habitica parameters not (yet) supported:
        #   priority, checklist, tags, date; attribute
        ttype = TaskType.TODO
        assert isinstance(ttype, TaskType)
        args = {'type': ttype.value, 'text': text}
        if notes is not None:
            args['notes'] = notes
        ret = self.__api.tasks.user.post(**args)
        if TasksType.TODOS in self.__task_cache:
            self.__task_cache[TasksType.TODOS].append(ret)
        return ret

    def delete_task_by_id(self, task_id, verbosity=None):
        if verbosity is None:
            verbosity = self.__verbosity
        ret = self.__api.tasks[task_id].delete()
        for k in self.__task_cache.keys():
            self.__task_cache[k] = [t for t in self.__task_cache[k]
                                    if t['id'] != task_id]
        if verbosity >= 1:
            print(f"(H) Task id '{task_id}' deleted", file=sys.stderr)
        return ret

    def find_task_by_type_and_name(self, ttype, text):
        assert isinstance(ttype, TaskType)
        tstype = task_to_tasks[ttype]
        assert isinstance(tstype, TasksType)
        for t in self._get_tasks(tstype):
            if t['text'] == text:
                return t
        return None

    def find_any_task_by_name(self, text):
        # first, try the existing cached types
        cached_ttypes = [tasks_to_task[ts] for ts in self.__task_cache.keys()
                         if ts in tasks_to_task]
        for t in cached_ttypes:
            found = self.find_task_by_type_and_name(t, text)
            if found:
                return found
        # otherwise, try all other types
        for t in TaskType:
            if t in cached_ttypes:
                continue
            found = self.find_task_by_type_and_name(t, text)
            if found:
                return found
        return None

    def delete_todo_by_name(self, text):
        task = self.find_task_by_type_and_name(TaskType.TODO, text)
        if task is None:
            if self.__verbosity >= 0:
                print(f"(H) Task named '{text}' not found", file=sys.stderr)
        else:
            self.delete_task_by_id(task['id'], verbosity=0)
            if self.__verbosity >= 1:
                print(f"(H) Task named '{text}' deleted", file=sys.stderr)
