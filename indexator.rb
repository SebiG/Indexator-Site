# encoding: UTF-8
require 'mysql2'  
require 'pp'
require 'set'
# require 'opal'
require 'nokogiri'
require 'json'
load 'metodeString.rb'
require 'yaml'
datesite = File.open('datesite.yaml')
datesite = YAML.load(datesite)
# pp datesite
module CuvinteStop #include cuvintele fara importanta de indexare
  @@cuvinteStopStr = "observa,acelasi,acest,acesteia,acestora,etc"
  @@cuvinteStopStr = @@cuvinteStopStr + "," + "acea,aceasta,aceasta,aceea,acei,aceia,acel,acela,acele,acelea,acest,acesta,aceste,acestea,acesti,acestia,acolo,acord,acum,ai,aia,aiba,aici,al,ala,ale,alea,alea,altceva,altcineva,am,ar,are,as,asadar,asemenea,asta,asta,astazi,astea,astea,astia,asupra,ati,au,avea,avem,aveti,azi,bine,bucur,buna,ca,ca,caci,cand,care,carei,caror,carui,cat,cate,cati,catre,catva,caut,ce,cel,ceva,chiar,cinci,cind,cine,cineva,cit,cite,citi,citva,contra,cu,cum,cumva,curand,curind,da,da,daca,dar,data,datorita,dau,de,deci,deja,deoarece,departe,desi,din,dinaintea,dintr,dintre,doi,doilea,doua,drept,dupa,ea,ei,el,ele,eram,este,esti,eu,face,fara,fata,fi,fie,fiecare,fii,fim,fiti,fiu,frumos,gratie,halba,iar,ieri,ii,il,imi,impotriva,in,inainte,inaintea,incat,incit,incotro,intre,intrucat,intrucit,iti,la,langa,le,li,linga,lor,lui,ma,mai,maine,mea,mei,mele,mereu,meu,mi,mie,miine,mine,mult,multa,multi,multumesc,ne,nevoie,nicaieri,nici,nimeni,nimeri,nimic,niste,noastra,noastre,noi,noroc,nostri,nostru,noua,nu,opt,ori,oricand,oricare,oricat,orice,oricind,oricine,oricit,oricum,oriunde,pana,patra,patru,patrulea,pe,pentru,peste,pic,pina,poate,pot,prea,prima,primul,prin,putin,putina,putina,rog,sa,sa,sai,sale,sapte,sase,sau,sau,se,si,sint,sintem,sinteti,spate,spre,stiu,sub,sunt,suntem,sunteti,suta,ta,tai,tale,tau,te,ti,tie,timp,tine,toata,toate,tot,toti,totusi,trei,treia,treilea,tu,un,una,unde,undeva,unei,uneia,unele,uneori,unii,unor,unora,unu,unui,unuia,unul,va,vi,voastra,voastre,voi,vostri,vostru,voua,vreme,vreo,vreun,zece,zero,zi,zice"
end

class Indexator
  include CuvinteStop
  include MetodeString

  def indexeaza(pagini)
      @hIDlexemSiFrati = {} #contine id lexem => flexiunile
      @index = {}
      @arrayFaraFamilie = []
      calculeazaScor(pagini)
  end

  def calculeazaScor(pagini)
      @pagini = diacriticeStrip(pagini)

      #####
      #pentru fiecare pagina, extrage cuvintele si calculeaza scorul
      #####
      hscor = {}
      # pp @pagini
      @pagini.each do |pagina|
        pscor = {}
        set = []
        pagina["titlu"].downcase.scan(/\w+'?\w+/) {|w| if not @@cuvinteStopStr.include?w then set << w end }
        set.each do |tkey| #calculez scorul in titlu
          pscor[tkey] ? pscor[tkey] += 1 : pscor[tkey] = 10
        end
        set = []
        Nokogiri::HTML(pagina["descriere"]).text.downcase.scan(/\w+'?\w+/) {|w| if not @@cuvinteStopStr.include?w then set << w end }
        set.each do |tkey| #calculez scorul in descriere
          pscor[tkey] ? pscor[tkey] += 1 : pscor[tkey] = 1
        end
        pscor = Hash[pscor.sort_by {|key,value| -1 * value }]
        hscor[pagina["iDpWeb"]] = pscor
      end

      #####
      #cuvant => pagini si scorul cuvantului pe acea pagina
      #####
      hcuvinte = {} #contine toate cuvintele de pe site si scorul lor global
      hscor.each do |idP, h|
        h.each do |cuvant, scor|
          hcuvinte[cuvant] ? hcuvinte[cuvant] += scor : hcuvinte[cuvant] = scor
        end
      end
      listaCuvantPaginiScor = {}
      hcuvinte.each do |c,v|
        l = {}
        hscor.each do |idP, h|
          if h.include?c then
            l[idP] = h[c]
          end
        end
        l = Hash[l.sort_by { |k,v| [-1 * v, -1 * k] }]
        listaCuvantPaginiScor[c] = l
      end

      listaCuvantPaginiScor = Hash[listaCuvantPaginiScor.sort_by { |k,v| k }]

      genereazaIndex(listaCuvantPaginiScor)
  end

  def surprizesurprize(arraylexeme)
      #salveaza in @hIDlexemSiFrati id => array cu toate formele lexicale
      arraylexeme.each do |hlexem|
        arrayFrati = Set.new
        formeCuv(hlexem["id"]).each do |cuvf|
          # unless arrayFrati.include?cuvf
            arrayFrati << cuvf.downcase
          # end
        end
        @hIDlexemSiFrati[hlexem["id"]] = arrayFrati
      end
  end

  def extragelexem(cuv) #extrage lexemul corespunzator cuvantului flexionat (cuvantul de baza, cu id)

      sqlqr = "SELECT DISTINCT `l`.* FROM `Lexem` `l` JOIN `LexemModel` `lm` ON l.id = lm.lexemId JOIN `InflectedForm` `f` ON lm.id = f.lexemModelId WHERE `f`.`formUtf8General` = '#{cuv}' ORDER BY `l`.`formNoAccent` ASC;"
      client = Mysql2::Client.new(:host => "localhost", :username => "root", :password => "qwer", :database => "dex", :encoding => 'utf8')
      arraylexeme = []
      excluderiDuplicat = [62510]
      excluderi = [190083,33170,100113,209214,189345,212241,165362,20836]  #Chile, Dove, Strat, fui, fi 
        client.query(sqlqr).each do |row|
        next if excluderi.include?row["id"]
        # if caut(row["formUtf8General"])
        #   p row["id"]
        #   p row["formUtf8General"]
        # end
        arraylexeme << row.select {|k,v| k == "id" or k == "formUtf8General" or k == "description"}
        end

      arraylexeme
  end

  def populezindex(arraylexeme)
      arrayFrati = Set.new
      arraylexeme.each do |hlexem|
         formeCuv(hlexem["id"]).each do |cuvf|
            # unless arrayFrati.include?cuvf
              arrayFrati << cuvf
            # end
         end
      end
      arrayFrati.each do |cuvf|
        @index[cuvf] = {}
      end
  end

  def formeCuv(id)
      #iau idlexem din hash si extrag toate formele flexionare din tabelul inflectedform unde idlexem se uneste cu formele prin idul LexemModel din tabelul lexemModel.
      #formele sunt accesate cu x.entries sub forma de row[column]
        # client = nil
      client = Mysql2::Client.new(:host => "localhost", :username => "root", :password => "qwer", :database => "dex", :encoding => 'utf8')
      sql = "SELECT inflectedform.formNoAccent AS flex FROM inflectedform INNER JOIN lexemmodel ON inflectedform.lexemModelId = lexemmodel.id WHERE lexemmodel.lexemId=#{id};"
      client.query("SET GLOBAL max_connections = 650;") #ridica limita conectii sql pentru a evita eroare Too many connections (Mysql2::Error)
      buzunar = Set.new
      client.query(sql,:as => :array).each do |row|
      x = diacriticeStrip(row[0])
        unless @@cuvinteStopStr.include?x
          buzunar << x
        end
      end
      buzunar    
  end

  def genereazaIndex(listaCuvantPaginiScor)
      indexator = {}
      familia = []

      listaCuvantPaginiScor.each do |cuv,rez|
      arraylexeme = extragelexem(cuv) #contine un array de randuri, coloane: id, formUtf8General, description.
        if arraylexeme.count == 0 then
          @arrayFaraFamilie << cuv
          # p "cuvantul #{cuv} nu este in dictionar"
          next
        else
          surprizesurprize(arraylexeme) #creaza un index in @hIDlexemSiFrati cu formle flexionare pentru fiecare intels (id => )
          populezindex(arraylexeme) #@index cu toate cuvintele flexionate => {}
          
        end
      end

      @index.each do |cuvf,h| #cuvant flexionat

            scorFamilie = {}      
        @hIDlexemSiFrati.each do |id,f| #id lexem si frati de inteles
          if f.include?cuvf then #caut familia de inteles ce include cuvf si

            f.each do |f| #pentru fiecare dintre frati
              if listaCuvantPaginiScor[f] #extrag scorul daca exista

                  listaCuvantPaginiScor[f].each do |p,s| #pagina si scor
                    scorFamilie[p] ? scorFamilie[p] += s : scorFamilie[p] = s #aduna scorurile paginilor care apartin de aceasi famile
                  end #each

              end #if
            end #each frati

          end #if include

        end #each frati

          #caut in @hIDlexemSiFrati, extrag fratii, extrag rezultatele fratilor 
          #si apoi le unesc cu rezultatele lui => {pagina => scor}
            if listaCuvantPaginiScor[cuvf]
              # scorfamilie
              listaCuvantPaginiScor[cuvf].each do |p,s| #pagina si scor
                scorFamilie[p] ? scorFamilie[p] += s : scorFamilie[p] = s #aduna scorurile paginilor care apartin de aceasi famile
              end
              @index[cuvf] = scorFamilie #dubleaza scorul cuvantului indexat pentru departajare
            else
              @index[cuvf] = scorFamilie #doar scorul familiei
            end 
      end
            #insereaza in index cuvintele care nu sunt gasite in dictionar
            @arrayFaraFamilie.each do |cuv|

              @index[cuv] = listaCuvantPaginiScor[cuv]
            end

            #ordoneaza
            # @index = Hash[@index.sort_by { |k,v| [-1 * v, -1 * k] }]
      @index = @index.sort.to_h

          # pp @index
        # p "*****************"
  end

  def salveazaJson(nume)
    nume = nume + '.json'
    # pp @index
    # x = JSON.generate(@index, :encoding => "UTF-8")
    File.write('exceptii-' + nume, JSON.pretty_generate(@arrayFaraFamilie, :encoding => "UTF-8"))
    File.write(nume, JSON.generate(@index, :encoding => "UTF-8"))
  end

  def caut(aaa)
    if aaa[0] =~ /[CDS]/
        p "i-am gasit"
      end
  end

    def indextoconsola
        pp @index
    end
end #class

i = Indexator.new
i.indexeaza(datesite)
i.indextoconsola
# p i.extragelexem("casa")
# i.salveazaJson("test")

#"seminte"=>{4=>1, 3=>1, 2=>2} -- cuvant => {id pagina => scor}

