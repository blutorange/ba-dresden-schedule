require_relative './mailer.rb'
require_relative './passwords.rb'

        now = Time.now
        date = "%04d/%02d/%02d" % [now.year,now.month,now.day]
        Mailer.sendMail( 
            :subject     => "#{date} Raspberry PI running confirmation",
            :body        => "I am still running. You did not screw up.",
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
