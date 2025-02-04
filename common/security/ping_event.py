#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2017 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Danni Als, Carsten Agger, Marcus Funch, Søren Howe Gersager, Andreas Poulsen

"""An example of how to write a security script, useful for testing that the security system works."""

from datetime import datetime


def csv_writer(security_events):
    """Write security events to security events file."""
    with open("/etc/os2borgerpc/security/securityevent.csv", "at") as csvfile:
        for timestamp, security_problem_uid, log_event in security_events:
            event_line = log_event.replace("\n", " ").replace("\r", "").replace(",", "")
            csvfile.write(f"{timestamp},{security_problem_uid},{event_line}\n")


now = datetime.now()
timestamp = datetime.strftime(now, "%Y%m%d%H%M%S")
security_problem_uid_template_var = "%SECURITY_PROBLEM_UID%"
log_event = "Ping warning."


csv_writer([(timestamp, security_problem_uid_template_var, log_event)])
