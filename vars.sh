#!/usr/bin/env bash


# Override SSH port if desired:
SSH_PORT=2222

# Override the root password if desired:
PASSWORD_ROOT="mysecurepassword"

# Define admin users as username:password pairs (space-separated for multiple).
# If password is omitted after ':', it defaults to "adminpassword".
# For example:
ADMIN_USERS="admin1: admin2:secretadminpass"

# If you do not set ADMIN_USERS, the script prompts and defaults to "adminuser:adminpassword".

# Define which users should have NOPASSWD sudo access:
# List the usernames that should have NOPASSWD separated by spaces.
# If none are listed, no user gets NOPASSWD:
NOPASS_ADMIN="admin1 admin2"

