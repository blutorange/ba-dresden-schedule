#!/usr/bin/env ruby

require 'time'
require 'google_calendar'
require_relative './getSchedule.rb'
require_relative './passwords.rb'
require_relative './config.rb'
require_relative './utils.rb'
require_relative './mailer.rb'

class WrapperGoogleCalendar
    GOOGLE_EVENT_BACKGROUND_COLOR_IDS = {}

    def self.setRefreshToken(rToken)
        Passwords.storeGcalRefreshToken(rToken)
    end

    def self.getRefreshToken
        Passwords.gcalRefreshToken
    end

    def self.getCalEventTime(time)
        if time.is_a?(Time)
            time
        else
            begin
                Time.strptime(time.to_s,"%Y-%m-%dT%H:%M:%S%:z")
            rescue StandardError
                Time.strptime("0","%s")
            end
        end
    end

    def self.retrieveEventBackgroundColorIds(conn)
        GOOGLE_EVENT_BACKGROUND_COLOR_IDS.clear
        colorJson = JSON.parse(conn.send("/colors",:get,"").body)
        colorJson["event"].each_pair do |id,colors|
            if c=colors["background"].match(/#?([0-9a-f]+)/i)
                GOOGLE_EVENT_BACKGROUND_COLOR_IDS[id] = Utils.colorFromHex(c[1])
            end
        end
    end

    def self.deleteEvent(event)
        event.delete
        sleep 1
    end
    def self.newEvent(cal,&block)
        event = cal.create_event(&block)
        sleep 1
        event
    end
    def self.saveEvent(cal,event)
        cal.save_event(event)
        sleep 1
    end

    # Color distance in r=(h,s,l): (r1_i-r2_i)^2
    # Weights: w = (4,1,1)
    def self.getGoogleColorId(sCol)
        if (sCol)
            GOOGLE_EVENT_BACKGROUND_COLOR_IDS.min_by do |id,gCol|
                d = (gCol[:h]-sCol[:h]).abs
                (4*4)*[d,1.0-d].min**2+(gCol[:s]-sCol[:s])**2+(gCol[:l]-sCol[:l])**2
            end[0]
        else
            GOOGLE_EVENT_BACKGROUND_COLOR_IDS.first[0]
        end
    end

    def self.buildGoogleDescription(evFrom)
        evFromDesc = Utils.setStringDefault(UpdaterCalendar.getScheduleEventDesc(evFrom), "Keine Beschreibung vorhanden.")
        evFromRoom = Utils.setStringDefault(UpdaterCalendar.getScheduleEventRoom(evFrom), "Kein Raum angegeben.")
        evFromInstructor = Utils.setStringDefault(UpdaterCalendar.getScheduleEventInstructor(evFrom), "Keine Lehrperson angegeben.")
        evFromRemarks = Utils.setStringDefault(UpdaterCalendar.getScheduleEventRemarks(evFrom),nil)
        desc = ["Raum: #{evFromRoom}",
                "Lehrender: #{evFromInstructor}",
                "#{evFromDesc}",
                evFromRemarks ? "Bemerkungen: #{evFromRemarks}" : nil,
               ].compact.join(?\n)
        desc.gsub("\n","\\n")
    end

    def self.setCalEventData(evTo,evFrom)
        changed = false
        oldStartTime = getCalEventTime(evTo.start_time)
        oldEndTime = getCalEventTime(evTo.end_time)
        evToStart = UpdaterCalendar.getScheduleEventStartTime(evFrom)
        evToEnd = UpdaterCalendar.getScheduleEventEndTime(evFrom)
        evToEnd = evToStart+60 if (evToEnd-evToStart).abs<60
        evToDesc = WrapperGoogleCalendar.buildGoogleDescription(evFrom)
        evToLocation = Utils.setStringDefault(UpdaterCalendar.getScheduleEventRoom(evFrom),nil)
        evToTitle = Utils.setStringDefault(UpdaterCalendar.getScheduleEventTitle(evFrom),"Kein Titel vorhanden.")
        evToColorId = WrapperGoogleCalendar.getGoogleColorId(UpdaterCalendar.getScheduleEventColorCode(evFrom))
        changed = evTo.title != evToTitle || 
                  evTo.description.gsub("\n","\\n") != evToDesc ||
                  (oldStartTime-evToStart).abs >= 60 ||
                  (oldEndTime-evToEnd).abs >= 60 ||
                  evTo.location != evToLocation.to_s ||
                  evTo.color_id != evToColorId
        evTo.title = evToTitle
        evTo.description = evToDesc
        evTo.start_time = evToStart
        evTo.end_time = evToEnd
        evTo.location = evToLocation ? evToLocation : ''
        evTo.color_id = evToColorId
        changed
    end

    # Loads the calendar.
    def initialize
        rToken = WrapperGoogleCalendar.getRefreshToken
        @cal = Google::Calendar.new(:client_id     => Passwords.gcalClientId, 
                                    :client_secret => Passwords.gcalClientSecret,
                                    :calendar      => Config::GCAL_ID,
                                    :redirect_url  => Config::GCAL_REDIRECT_URL
                                   )
        if rToken
            @cal.login_with_refresh_token(rToken)
        else
           $stderr.puts "Enter access token from the following address:"
           puts @cal.authorize_url
           aCode = $stdin.gets.chomp
           rToken = @cal.login_with_auth_code(aCode)
           WrapperGoogleCalendar.setRefreshToken(rToken)
        end
        @events = @cal.events
        $stderr.puts "calendar loaded successfully"
        WrapperGoogleCalendar.retrieveEventBackgroundColorIds(@cal.connection)
    end

    # Deletes all events ending before (Time)timeFrom
    def deletePastEvents(timeFrom)
        @events.select do |event|
            eTime = WrapperGoogleCalendar.getCalEventTime(event.end_time)
            if eTime < timeFrom
                $stderr.puts "deleting old event"
                $stderr.puts event
                WrapperGoogleCalendar.deleteEvent(event)
            end
        end
    end

    # Deletes all events for which the block returns a falsey value.
    # The block takes the start and end time of each events as arguments.
    def deleteRemovedEvents()
        @events.each do |evTo|
            evToStart = WrapperGoogleCalendar.getCalEventTime(evTo.start_time)
            evToEnd = WrapperGoogleCalendar.getCalEventTime(evTo.end_time)
            evFrom = yield(evToStart,evToEnd)
            if !evFrom
                $stderr.puts "deleting removed event"
                $stderr.puts evTo
                WrapperGoogleCalendar.deleteEvent(evTo)
            end
        end
    end

    # Finds and returns the event starting at (Time)evFromStart and
    # ending at (Time)evFromEnd.
    # Return nil if no such event exists.
    # The event may be any object, it is then passed to 
    # updateEvent and #createEvent.
    def findEvent(evFromStart,evFromEnd)
        ev = nil
        @events.find do |event|
            evToStart = WrapperGoogleCalendar.getCalEventTime(event.start_time)
            evToEnd = WrapperGoogleCalendar.getCalEventTime(event.end_time)
            if (evFromStart-evToStart).abs < Config::UCALENDAR_SAME_TIME_THRESHOLD && (evFromEnd-evToEnd).abs < Config::UCALENDAR_SAME_TIME_THRESHOLD
                ev = event
                break
            end
        end
        ev
    end

    # Updates the event evTo with data from evFrom.
    # evTo is the object returned by #findEvent.
    # UpdaterCalendar provides these methods:
    #   getScheduleEventStartTime(evFrom)  => Time
    #   getScheduleEventEndTime(evFrom)    => Time
    #   getScheduleEventColorCode(evFrom)  => Number 0x000000-0xFFFFFF
    #   getScheduleEventRoom(evFrom)       => String
    #   getScheduleEventDesc(evFrom)       => String
    #   getScheduleEventTitle(evFrom)      => String
    #   getScheduleEventInstructor(evFrom) => String
    #   getScheduleEventRemarks(evFrom)    => String
    def updateEvent(evTo,evFrom)
        changed = WrapperGoogleCalendar.setCalEventData(evTo,evFrom)
        if changed
            WrapperGoogleCalendar.saveEvent(@cal,evTo)
        else
            $stderr.puts "nothing to update"
        end
    end

    # Creates a new event from evFrom.
    # See #updateEvent for details on how to access event details in evFrom.
    def createEvent(evFrom)
        WrapperGoogleCalendar.newEvent(@cal) do |evTo|
            WrapperGoogleCalendar.setCalEventData(evTo,evFrom)
        end
    end

    # Filters the events in the calendar.
    # Only events for which the block returns true shall be processed.
    # Events shall not be modified by this method.
    # The block gets passed the title and description for each events.
    def filter!
        @events.select! do |event|
            yield(event.title,event.description)
        end
    end

end

class WrapperCalDav
    # Loads the calendar.
    def initialize
    end

    # Deletes all events ending before (Time)timeFrom
    def deletePastEvents(timeFrom)
    end

    # Deletes all events for which the block returns a falsey value.
    # The block takes the start and end time of each events as arguments.
    def deleteRemovedEvents()
    end

    # Finds and returns the event starting at (Time)evFromStart and
    # ending at (Time)evFromEnd.
    # Return nil if no such event exists.
    # The event may be any object, it is then passed to #updateEvent.
    def findEvent(evFromStart,evFromEnd)
    end

    # Updates the event evTo with data from evFrom.
    # evTo is the object returned by #findEvent.
    # UpdaterCalendar provides these methods:
    #   getScheduleEventStartTime(evFrom)  => Time
    #   getScheduleEventEndTime(evFrom)    => Time
    #   getScheduleEventColorCode(evFrom)  => Number 0x000000-0xFFFFFF
    #   getScheduleEventRoom(evFrom)       => String
    #   getScheduleEventDesc(evFrom)       => String
    #   getScheduleEventTitle(evFrom)      => String
    #   getScheduleEventInstructor(evFrom) => String
    #   getScheduleEventRemarks(evFrom)    => String
    def updateEvent(evTo,evFrom)
    end

    # Creates a new event from evFrom.
    # See #updateEvent for details on how to access event details in evFrom.
    def createEvent(evFrom)
    end
end

module UpdaterCalendar
  
    # (now-2days...now+2weeks)
    def self.getScheduleTimeFrame
        now = Time.now
        today = now-now.hour*3600 - now.min*60 - now.sec
        timeFrom = today - Config::UCALENDAR_PAST_EVENTS_THRESHOLD
        timeTo = today + Config::UCALENDAR_FUTURE_EVENTS_THRESHOLD
        [timeFrom,timeTo]
    end

    def self.getScheduleEventRoom(evFrom)
        evFrom["room"]
    end
    def self.getScheduleEventTitle(evFrom)
        evFrom["title"]
    end
    def self.getScheduleEventDesc(evFrom)
        evFrom["description"]
    end
    def self.getScheduleEventRemarks(evFrom)
        evFrom["remarks"]
    end
    def self.getScheduleEventInstructor(evFrom)
        evFrom["instructor"]
    end

    # Unix timestamp.
    def self.getScheduleEventTime(time)
        if time.is_a?(Time)
            time
        else
            begin
                Time.strptime(time.to_s,'%s')
            rescue StandardError
                Time.strptime("0","%s")
            end
        end
    end

    def self.findScheduleEvent(evToStart,evToEnd,schedule)
        ev = nil
        schedule.each do |scheduleEvent|
            evFromStart = getScheduleEventTime(scheduleEvent['start'])
            evFromEnd = getScheduleEventTime(scheduleEvent['end'])
            if (evFromStart-evToStart).abs < Config::UCALENDAR_SAME_TIME_THRESHOLD && (evFromEnd-evToEnd).abs < Config::UCALENDAR_SAME_TIME_THRESHOLD
                ev = scheduleEvent
                break
            end
        end
        ev
    end

    def self.getScheduleEventStartTime(evFrom)
        getScheduleEventTime(evFrom["start"])
    end
    def self.getScheduleEventEndTime(evFrom)
        getScheduleEventTime(evFrom["end"])
    end

    def self.getScheduleEventColorCode(evFrom)
        if (c = evFrom["color"].match(/#?([0-9a-f]+)/i))
            Utils.colorFromHex(c[1])
        else 
            Utils.colorFromHex('000000')
        end
    end

    def self.deletePastEvents(cal,timeFrom)
        cal.deletePastEvents(timeFrom)
    end

    def self.deleteRemovedEvents(cal,schedule)
        cal.deleteRemovedEvents do |evToStart,evToEnd|
            findScheduleEvent(evToStart,evToEnd,schedule)
        end
    end

    def self.addAddedEvents(cal,schedule)
        schedule.each do |evFrom|
            evFromStart = getScheduleEventTime(evFrom["start"])
            evFromEnd = getScheduleEventTime(evFrom["end"])
            evTo = cal.findEvent(evFromStart,evFromEnd)
            if evTo
                $stderr.puts "updating added event"
                cal.updateEvent(evTo,evFrom)
            else
                $stderr.puts "creating added event"
                evTo = cal.createEvent(evFrom)
            end
            $stderr.puts evFrom
            $stderr.puts evTo
        end
    end

    def self.limitScheduleEventsToTimeFrame(schedule,from,to)
        schedule.select do |event|
            eStart = getScheduleEventTime(event["start"])
            eEnd = getScheduleEventTime(event["end"])
            !(eEnd<from || eStart > to)
        end
    end

    # First delete all events in the distant past.
    # Then iterate over all events from the schedule
    # and update events on google calendar.
    def self.syncToCalendar(cal,schedule,timeFrom,timeTo)
        now = Time.now
        schedule = limitScheduleEventsToTimeFrame(schedule,timeFrom,timeTo)
        deletePastEvents(cal,timeFrom)
        addAddedEvents(cal,schedule)
        deleteRemovedEvents(cal,schedule)
    end

    def self.informViaMail(subject,body)
        Mailer.sendMail( 
            :subject     => subject,
            :body        => body,
            :from        => "sensenmann5@gmail.com",
            :to          => "sensenmann5@gmail.com",
            :smtpAddress => "smtp.gmail.com",
            :smtpPort    => "587",
            :smtpDomain  => "keterburg.snow.net",
            :smtpUserName => Passwords.gmailUserName,
            :smtpPassword => Passwords.gmailPassword,
            :smtpAuthentication => "plain",
            :smtpEnableStartTlsAuto => true,
        )
    end
    
    def self.updateCalendar(*calendars)
        begin
            timeFrom, timeTo = getScheduleTimeFrame
            schedule = ScheduleGetterBasic.getSchedule(Passwords.selfserviceUserName,Passwords.selfservicePassword,timeFrom,timeTo)
        rescue Exception => e
            $stderr.puts "failed to load schedule"
            $stderr.puts e
            $stderr.puts e.message
            $stderr.puts e.backtrace
            informViaMail("[[!ERROR!]] Selfservice Updater","Something went wrong while downloading the BA schedule! Please gimme a fix.\n"+
                                    "Error details:\n" +
                                    e.class.to_s + "\n" +
                                    e.message + "\n" +
                                    e.backtrace.to_s
                             )
            exit 1
        end
        calendars.each do |calendar|
            begin
                cal = calendar.new
                cal.filter! do |title,desc|
                    !desc.is_a?(String) || desc[0..7] != "<<MISC>>"
                end
                syncToCalendar(cal,schedule,timeFrom,timeTo)
            rescue Exception=>e
                $stderr.puts "failed updating calendar #{calendar}"
                $stderr.puts e
                $stderr.puts e.message
                $stderr.puts e.backtrace
                informViaMail("[[!ERROR!]] Selfservice Updater","Something went wrong while updating #{calendar}! Please gimme a fix.\n"+
                                    "Error details:\n" +
                                    e.class.to_s + "\n" +
                                    e.message + "\n" +
                                    e.backtrace.to_s
                             )
                exit 1
            end
        end
    end
end

UpdaterCalendar.updateCalendar(WrapperGoogleCalendar)
