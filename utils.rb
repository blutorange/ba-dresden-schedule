require 'color'
module Utils
    def self.setStringDefault(str,dflt)
        (str.is_a?(String) && !str.empty?) ? str : dflt
    end

    def self.colorFromHex(hex)
        code = hex.to_i(16)
        r = (code&0xFF0000)>>16
        g = (code&0x00FF00)>>8
        b = (code&0x0000FF)>>0
        color = Color::RGB.new(r,g,b)
        hsl = color.to_hsl
        {:r=>r,:g=>g,:b=>b,:h=>hsl.h,:s=>hsl.s,:l=>hsl.l}
    end
end

