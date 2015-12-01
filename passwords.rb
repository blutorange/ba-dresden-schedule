require 'json'
require_relative './config.rb'
module Passwords
    FILE = Config::UCALENDAR_PASSWORD_FILE
    KEYRING = JSON.parse(File.read(FILE))
    def self.store(key,val)
      KEYRING[key] = val
      File.write(FILE,JSON.pretty_generate(KEYRING))
    end

    def self.gmailUserName
        KEYRING['gmailUserName']
    end
    def self.gmailPassword
        KEYRING['gmailPassword']
    end
    def self.gcalClientId
        KEYRING['gcalClientId']
    end
    def self.gcalDevKey
        KEYRING['gcalDevKey']
    end
    def self.gcalClientSecret
        KEYRING['gcalClientSecret']
    end
    def self.selfserviceUserName
        KEYRING['selfserviceUserName']
    end
    def self.selfservicePassword
        KEYRING['selfservicePassword']
    end
    def self.cdavUser
        KEYRING['cdavuser']
    end
    def self.cdavPassword
        KEYRING['cdavPassword']
    end
    def self.gcalRefreshToken
        KEYRING['gcalRefreshToken']
    end

    def self.storeGcalRefreshToken(rToken)
        store('gcalRefreshToken',rToken)
    end
end
