Script for downloading the schedule from selfservice.campus-dual.de and
uploading it to google calendar.

The main program is updateCalendar, run with no arguments:
  $ ruby updateCalendar.rb
This will retrieve the schedule from selfservice.campus-dual.de, synchronize
it with google calendar, and send a mail to your google mail account if some-
thing went wrong.

Add a cron job to run this script periodically and keep the calendar up-to-date.

Requires a few gems to be installed:
  $ gem json curb nokogiri mail google_calendar color

A few options must be configured, see config.rb for details and the passwords file.
