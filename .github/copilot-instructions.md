# AI Assistant Instructions for velebit-scripts

## Repository Overview
This repository is a collection of various scripts organized by domain, with no central organizing principle beyond being "random scripts" that have been created by the user. The user has placed the scripts that are or were ready to be made "publicly available" into the `develop` branch, but some of those scripts may be out of date or obsolete. Another branch contains scripts that are still in development or are otherwise not ready for public release. The repository contains scripts for system administration, music file manipulation, productivity/task management, calendar operations, parenting tools, puzzles, and more.

## Repository Structure
The repository is organized into domain-specific directories, which include:
- `calendar/`: Date conversion and calendar manipulation scripts
- `dev_helpers/`: Development utilities
- `music/`: Music file manipulation (ID3 tags, MIDI files, etc.)
- `net-slurp/`: Utilities for extracting data from specific network (mostly web) servers
- `parenting/`: Scripts for parental controls and child account management
- `sysadmin/`: System administration utilities
- `tasks/`: Integration with productivity tools (Trello, Habitica, Miro, Toggl Track)
- `user/`: User-specific utilities
This organization is not consistently applied, and you should suggest improvements if you notice better ways to structure the repository.

## Key Patterns

### Script Execution Patterns
- Many of the Python scripts use shebang paths pointing to user-specific Python virtual environments:
  ```python
  #!/home/bert/.local/lib/python/venv/default/bin/python3 -B
  ```
  or
  ```python
  #!/home/bert/.local/lib/python/venv/tasks/bin/python3
  ```

- Some scripts use a non-executable marker such as:
  ```python
  #!/not-executable/python3
  ```
  These are meant to be imported, not executed directly.

### Library Structure
- Domain-specific Python modules (e.g., `id3tools.py`, `bert_trello.py`) contain shared functionality used by the executable scripts in the same directory.
- Common utilities are often shared within a directory (e.g., `bert_task_utilities.py` for the tasks directory).

### Authentication Handling
- Authentication credentials are typically stored in user config directories:
  ```python
  def get_auth_file_name():
      home_dir = os.getenv("HOME")
      assert home_dir is not None, "HOME needs to be set"
      return home_dir + "/.config/bert_trello/auth.json"
  ```

### Command Line Interface Patterns
- Most Python scripts use `argparse` for command-line argument parsing.
- Scripts follow a pattern of defining a `parse_args()` function that returns the parsed arguments.

### Shell Script Patterns
- Shell scripts (e.g., in `sysadmin/`, `parenting/`) often use functions and variables to configure behavior.
- Shell scripts in `parenting/` source a common `ll-functions.bash` file for shared functionality.

## Working with the Codebase

### Making Changes
- Each script is designed to be self-contained or with minimal dependencies on shared modules in the same directory.
- When modifying a script, check for other scripts that might import it as a module.
- Preserve the existing shebang lines when editing files.

### Testing Scripts
- Scripts do not have formal test suites. Test manually by running the script with appropriate arguments.
- Use the `-h` or `--help` flag to understand a script's usage before running it.

### Key Integration Points
- **Task Management**: Scripts in `tasks/` interact with external APIs like Trello, Habitica, Miro, and Toggl Track. They share common utility functions but have separate authentication.
- **Music File Management**: Scripts in `music/` work with ID3 tags and MIDI files, often importing shared functionality from `id3tools.py`.
- **System Administration**: Scripts in `sysadmin/` handle package management, partitioning, and system configuration.

### Dependencies
- Python scripts often rely on third-party packages like `eyed3`, `trello`, and `dateutil`.
- These dependencies would typically be installed in the virtual environments referenced in the shebang lines.