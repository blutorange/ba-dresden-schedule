module Config
    # google calendar id
    GCAL_ID = "cn6kb1u2aj0nnp59gl8etkjrtc@group.calendar.google.com"
    # google api redirect url, used when granting access to your google
    # account to this program
    GCAL_REDIRECT_URL = "urn:ietf:wg:oauth:2.0:oob"

    # All events older than 3 weeks will be removed.
    UCALENDAR_PAST_EVENTS_THRESHOLD = 21*24*3600 # 3 weeeks
    # Only events within the next 3 weeks will be added to google calendar.
    UCALENDAR_FUTURE_EVENTS_THRESHOLD = 21*24*3600 # 3 weeks
    # Threshold two events may be apart (temporally, start and end point)
    # and still be considered the same events.
    UCALENDAR_SAME_TIME_THRESHOLD = 60 # 1 minute

    # Password file containing the passwords for google calendar and selfservice.
    # Sample password file (json format):
    # {
    #   "selfserviceUserName": "1234567",
    #   "selfservicePassword": "secret",
    #   "gcalClientId": "999999999999-zzzzzzzzzzzzzzzzz.apps.googleusercontent.com",
    #   "gcalClientSecret": "AAAAAAAAAAAAAAAAAA",
    #   "gmailUserName": "example@gmail.com",
    #   "gmailPassword": "password"
    # }
    # The gmail user name and password is needed for sending mails to your
    # account to inform you when an error occured while update the schedule.
    UCALENDAR_PASSWORD_FILE = '/usr/local/etc/supdater-pwd'

    # Not used.
    SELFSERVICE_ENTRY_PAGE = "https://selfservice.campus-dual.de/"
    # Caldav uri, not implemented yet.
    CDAV_URI = ""
end
