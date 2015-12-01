require 'mail'
require_relative './passwords.rb'

module Mailer
    MAIL_SMTP_ADDRESS = "smtp.gmail.com"
    MAIL_SMTP_PORT = "587"
    MAIL_SMTP_DOMAIN = "keterburg.snow.net"
    MAIL_SMTP_AUTHENTICATION = "plain"
    MAIL_SMTP_ENABLE_STARTTLS_AUTO = true

    def self.sendMail(opts)
        subject = opts[:subject] || ""
        body = opts[:body] || ""
        from = opts[:from] || "me@example.com"
        toList = [opts[:to] || "you@example.com"].flatten
        attachments = opts[:attachments] || []
        smtpAddress = opts[:smtpAddress] || "localhost"
        smtpPort = opts[:smtpPort] || 25
        smtpDomain = opts[:smtpDomain] || "localhost.localdomain"
        smtpUserName = opts[:smtpUserName] || nil
        smtpPassword = opts[:smtpPassword] || nil
        smtpAuthentication = opts[:smtpAuthentication] || nil
        smtpEnableStarttlsAuto = opts[:smtpEnableStarttlsAuto].nil? ? true : opts[:smtpEnableStarttlsAuto]
        bcc = Mail::BccField.new
        toList.each{|t|bcc << t}

        mail = Mail.new do
            from     from
            to       from
            bcc      bcc
            subject  subject
            body     body
            attachments.each do |attachment|
                add_file :filename => attachment[:filename], :content => attachment[:content]
            end
        end
        mail.delivery_method(:smtp,{
            :address => smtpAddress,
            :port => smtpPort,
            :domain => smtpDomain,
            :user_name => smtpUserName,
            :password => smtpPassword,
            :authentication => smtpAuthentication,
            :enable_starttls_auto => smtpEnableStarttlsAuto
        })
        begin
            mail.deliver!
        rescue Exception => e
            $stderr.puts "failed delivering mail"
            $stderr.puts e
            $stderr.puts e.message
            $stderr.puts e.backtrace
            throw StandardError, "failed delivering mail"
        end
    end
end
