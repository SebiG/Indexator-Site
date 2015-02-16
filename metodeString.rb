module MetodeString

  def diacriticeStrip(s)
    if s.is_a?(String)
      strip(s)
    else
      require 'json'
      serial = JSON.generate(s, :encoding => "UTF-8")
      serial = strip(serial)
      serial = serial.gsub(/&nbsp;|\\r\\n?|\\.|\\,/, " ").gsub(/\s{2,}/, "")
      s = JSON.parse(serial)
    end
    # return s
  end
  def strip(s)
    s.gsub(/[țȚŢţ]/,"t").gsub(/[ăâĂÂ]/,"a").gsub(/[șȘşŞ]/,"s").gsub(/[îÎ]/, "i")
    # return s
  end
# test_diacritice
  def test_diacritice
    t = "1 î Î 2 â Â 3 ă Ă 4 ș Ș 5 ț Ț 6 ş Ş 7 ţ Ţ \\\:2,\""
    t1 = diacriticeStrip(t)
    p t1
    if not t1 == "1 i i 2 a a 3 a a 4 s s 5 t t 6 s s 7 t t \\:2,\""
    then p "eroare! conversia diacriticelor nu functioneaza" + t1
    else
      p "merge: " + t1
    end
  end

end
