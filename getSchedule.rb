#TODO Do it with gem mechanize.

require 'curb'
require 'json'
require 'nokogiri'

module ScheduleGetterBasic
    def self.parseHeaders(h_str)
        headers = {}
        h_str.split("\r\n").each do |entry|
            if colon = entry.index(?:)
                key = entry[0..colon-1].strip.downcase
                val = entry[colon+1..-1].strip
                headers[key] ||= []
                headers[key] << val
            end
        end
        return headers
    end

    def self.parseCookies(c_str)
        cookies = {}
        c_str.split(?;).each do |entry|
            e = entry.scan(/([^=]+)=(.+)/)
            if e.length==1
                cookies[e.first.first.strip] = e.first.last.strip
            end
        end
        return cookies
    end

    def self.decodeURLParam(param)
        param.gsub(/\%([0-9a-f]{2})/i) do 
            $1.to_i(16).chr
        end
    end

    def self.getPHPSESSID
        url = "https://selfservice.campus-dual.de/"
        curl = Curl::Easy.new(url)
        curl.ssl_verify_host = 0
        curl.ssl_verify_peer = false
        curl.headers["Accept"] = "text/html,application/xhtml+xml,application/xml"
        curl.headers["Host"] = "selfservice.campus-dual.de"
        curl.headers["Upgrade-Insecure-Requests"] = "1"
        curl.perform
        headers = parseHeaders(curl.header_str)
        if (headers["set-cookie"].is_a?(Array))
            cookies = parseCookies(headers["set-cookie"][0])
            cookies["PHPSESSID"]
        end
    end

    def self.getLoginPage(phpsessid)
        url = "https://selfservice.campus-dual.de/index/login"
        curl = Curl::Easy.new(url)
        curl.ssl_verify_host = 0
        curl.ssl_verify_peer = false
        curl.headers["Cookie"] = "PHPSESSID=#{phpsessid}"
        curl.headers["Accept"] = "text/html,application/xhtml+xml,application/xml"
        curl.headers["Host"] = "selfservice.campus-dual.de"
        curl.headers["Referer"] = "https://selfservice.campus-dual.de/"
        curl.headers["Upgrade-Insecure-Requests"] = "1"
        curl.perform
        headers = parseHeaders(curl.header_str)
        headers["location"][0]
    end


    def self.getSapLogin(loginPage)
        inputs = {}
        url = loginPage
        curl = Curl::Easy.new(url)
        curl.ssl_verify_host = 0
        curl.ssl_verify_peer = false
        curl.headers["Accept"] = "text/html,application/xhtml+xml,application/xml"
        curl.headers["Host"] = "erp.campus-dual.de"
        curl.headers["Referer"] = "https://selfservice.campus-dual.de/"
        curl.headers["Upgrade-Insecure-Requests"] = "1"
        curl.perform
        headers = parseHeaders(curl.header_str)
        cookies = {}
        if (headers["set-cookie"].is_a?(Array))
            headers["set-cookie"].each do |c|
                cookies.merge!(parseCookies(c)||{})
            end
        end    
        html_doc = Nokogiri::HTML(curl.body_str)
        ["FOCUS_ID",
         "sap-system-login-oninputprocessing",
         "sap-urlscheme",
         "sap-system-login",
         "sap-system-login-basic_auth",
         "sap-client",
         "sap-language",
         "sap-accessibility",
         "sap-login-XSRF",
         "sap-system-login-cookie_disabled"].each do |name|
            inputs[name] = html_doc.xpath("//input[@name='#{name}']")[0].attr("value")
        end
        return cookies["sap-login-XSRF_ERP"],cookies["sap-usercontext"],inputs
    end


    def self.doLoginStep1(loginPage1,sapLogin,sapUserContext,inputs,username,password)
        sapLanguage = sapUserContext.scan(/sap\-language=([a-z]+)/i)[0][0]
        sapClient = sapUserContext.scan(/sap\-client=(\d+)/i)[0][0]
        url = "https://erp.campus-dual.de/sap/bc/webdynpro/sap/zba_initss?uri=https%3a%2f%2fselfservice.campus-dual.de%2findex%2flogin"
        formFields = []
        formFields << Curl::PostField.content("FOCUS_ID",inputs["FOCUS_ID"])
        formFields << Curl::PostField.content("sap-system-login-oninputprocessing",inputs["sap-system-login-oninputprocessing"])
        formFields << Curl::PostField.content("sap-urlscheme",inputs["sap-urlscheme"])
        formFields << Curl::PostField.content("sap-system-login",inputs["sap-system-login"])
        formFields << Curl::PostField.content("sap-system-login-basic_auth",inputs["sap-system-login-basic_auth"])
        formFields << Curl::PostField.content("sap-client",inputs["sap-client"])
        formFields << Curl::PostField.content("sap-language",inputs["sap-language"])
        formFields << Curl::PostField.content("sap-accessibility",inputs["sap-accessibility"])
        formFields << Curl::PostField.content("sap-login-XSRF",inputs["sap-login-XSRF"])
        formFields << Curl::PostField.content("sap-system-login-cookie_disabled",inputs["sap-system-login-cookie_disabled"])
        formFields << Curl::PostField.content("sap-user",username)
        formFields << Curl::PostField.content("sap-password",password)
        curl = Curl::Easy.http_post(url,'SAPEVENTQUEUE=Form_Submit%7EE002Id%7EE004SL__FORM%7EE003%7EE002ClientAction%7EE004submit%7EE005ActionUrl%7EE004%7EE005ResponseData%7EE004full%7EE005PrepareScript%7EE004%7EE003%7EE002%7EE003',*formFields) do |c|
            c.ssl_verify_host = 0
            c.ssl_verify_peer = false
            c.follow_location = false
            c.headers["Content-Type"]="application/x-www-form-urlencoded"
            c.headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"#
            c.headers["Cache-Control"] = "max-age=0"
            c.headers["Host"] = "erp.campus-dual.de"
            c.headers["Origin"] = "https://erp.campus-dual.de"
            c.headers["Upgrade-Insecure-Requests"] = 1
            c.headers["Referer"] = loginPage1
            c.headers["Cookie"] = "sap-login-XSRF_ERP=#{sapLogin}; sap-usercontext=#{sapUserContext}"
        end
        headers = parseHeaders(curl.header_str)
        cookies = {}
        if (headers["set-cookie"].is_a?(Array))
            headers["set-cookie"].each do |c|
                cookies.merge!(parseCookies(c)||{})
            end
        end  
        mysapss02 = cookies["MYSAPSSO2"]
        if curl.response_code==200
        elsif curl.response_code==302
            doLoginStep2(loginPage1,headers["location"][0],mysapss02,sapUserContext)
        end
        return mysapss02,cookies["sap-login-XSRF_ERP"],cookies["sap-usercontext"]
    end

    def self.doLoginStep2(loginPage1,loginPage2,mysapss02,sapUserContext)
        url = "https://erp.campus-dual.de" + loginPage2
        curl = Curl::Easy.new(url)
        curl.ssl_verify_host = 0
        curl.ssl_verify_peer = false
        curl.headers["Accept"] = "text/html,application/xhtml+xml,application/xml"
        curl.headers["Host"] = "erp.campus-dual.de"
        curl.headers["Referer"] = loginPage1
        curl.headers["Upgrade-Insecure-Requests"] = "1"
        curl.headers["Cookie"] = "sap-usercontext=#{sapUserContext}; MYSAPSSO2={#mysapss02}"
        curl.perform
    end

    def self.getHash(phpsessid,mysapss02)
        url = "https://selfservice.campus-dual.de/room/index"
        curl = Curl::Easy.new(url)
        curl.ssl_verify_host = 0
        curl.ssl_verify_peer = false
        curl.headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
        curl.headers["Host"] = "selfservice.campus-dual.de"
        curl.headers["Referer"] = "https://selfservice.campus-dual.de/index/login"
        curl.headers["Upgrade-Insecure-Requests"] = "1"
        curl.headers["Cookie"] = "PHPSESSID=#{phpsessid}; MYSAPSSO2=#{decodeURLParam(mysapss02)}"
        curl.perform
        htmlDoc = Nokogiri::HTML(curl.body_str)
        htmlDoc.xpath("//script[@type='text/javascript']").each do |script|
            js = script.inner_html
            if (h=js.match(/hash[ \n;]*=[ \n;]*(["'])([0-9a-f]+)\1/))
                return h[2]
            end
        end
    end

    def self.getScheduleJson(phpsessid,mysapss02,hash,userId,timeFrom,timeTo)
        startTS = timeFrom.strftime("%s")
        endTS = timeTo.strftime("%s")
        curTS = Time.now.strftime("%s")
        url = "https://selfservice.campus-dual.de/room/json?userid=#{userId}&hash=#{hash}&start=#{startTS}&end=#{endTS}&_=#{curTS}"
        curl = Curl::Easy.new(url)
        curl.ssl_verify_host = 0
        curl.ssl_verify_peer = false
        curl.headers["Accept"] = "application/json"
        curl.headers["Host"] = "selfservice.campus-dual.de"
        curl.headers["Referer"] = "https://selfservice.campus-dual.de/room/index"
        curl.headers["Cookie"] = "PHPSESSID=#{phpsessid}; MYSAPSS02=#{mysapss02}"
        curl.perform
        JSON.parse(curl.body_str)
    end

    def self.doLogout(phpsessid,mysapss02)
        url = "https://selfservice.campus-dual.de/index/logout"
        curl = Curl::Easy.new(url)
        curl.ssl_verify_host = 0
        curl.ssl_verify_peer = false
        curl.headers["Accept"] = "text/html,application/xhtml+xml,application/xml"
        curl.headers["Host"] = "selfservice.campus-dual.de"
        curl.headers["Upgrade-Insecure-Requests"] = "1"
        curl.headers["Cookie"] = "PHPSESSID=#{phpsessid}; MYSAPSSO2={#mysapss02}"
        curl.perform
        raise StandardError,"failed to logout" unless curl.response_code==200
    end

    # Schedule is array of json objects, eg.:
    # {"title":"Prog ","start":1448275500,"end":1448280900,"allDay":false,"description":"Prog ","color":"0070a3","editable":false,"room":"3.204","sroom":"3.204","instructor":"Eberhard Engelhardt","sinstructor":"Eberhard Engelhardt","remarks":""}
    # Start / end time is unix time stamp.
    def self.getSchedule(username,password,timeFrom,timeTo)
        $stderr.puts "retrieving schedule schedule with username from #{timeFrom} to #{timeTo}"
        phpsessid = getPHPSESSID
        loginPage1 = getLoginPage(phpsessid)
        sapLogin,sapUserContext,inputs = getSapLogin(loginPage1)
        $stderr.puts "sapUserContext="+sapUserContext
        mysapss02,sapLogin,sapUserContext = doLoginStep1(loginPage1,sapLogin,sapUserContext,inputs,username,password)
        hash = getHash(phpsessid,mysapss02)
        scheduleJson = getScheduleJson(phpsessid,mysapss02,hash,username,timeFrom,timeTo)
        $stderr.puts "scheduleJson.length="+scheduleJson.length.to_s
        doLogout(phpsessid,mysapss02)
        $stderr.puts "logout successfull"
        scheduleJson
    end
end
