#include "DIRECTRY.CH"
#INCLUDE "fileio.ch"
#INCLUDE "error.ch"

static v_sugln,v_naam,v_adres,v_plaats,v_btwnr,v_waarde:="XXX",v_vandaag:=""

function profit_invoice()
local farray,v_file,x,arlen,v_del:="Y",v_outbox,v_snr,objLocal, bLastHandler,v_at1:=0,v_at2,v_at3

bLastHandler := ERRORBLOCK({ |objLocal| s247errorhandler(objLocal) })
//
BEGIN SEQUENCE

v_vandaag:=dtos(date())

use vrachtk.dbf alias vrachtk new
index on vrachtk->deartnr to vrachtk
set index to vrachtk

use f247fkop.dbf alias f247fkop new
zap
index on f247fkop->fakt_num to f247fkop
set index to f247fkop

use f247freg.dbf alias f247freg new
zap
index on f247freg->s_nr to f247freg
set index to f247freg

use invoicesend.dbf alias invoicesend new
index on fnum to invoicsend
set index to invoicsend

set century on
set epoch to 1960
set date ital
set deleted on

dbselectarea("f247fkop")
zap
dbselectarea("f247freg")
zap

if file("PEACOCK_INVOIC.INI")
  ofile:=tfileread():new("PEACOCK_INVOIC.INI")
  ofile:open()
  if ofile:error()
    qout( ofile:errormsg( "fileread: PEACOCK_INVOIC.INI" ) )
  else
    while ofile:moretoread()
      v_line:=alltrim(ofile:readline())
      if upper(left(v_line,9))="EIGEN GLN"
        v_sugln:=alltrim(substr(v_line,16,50))
      endif
      if upper(left(v_line,9))="EIGEN BTW"
        v_btwnr:=alltrim(substr(v_line,16,50))
      endif
      if upper(left(v_line,10))="FACTUURMAP"
        v_invmap:=trim(substr(v_line,16,256))
      endif
      if upper(left(v_line,24))="[VRACHTKOSTEN ARTIKELEN]"
        dbselectarea("VRACHTK")
        zap
        v_line:=alltrim(ofile:readline())
        v_line:=alltrim(ofile:readline())
        while ofile:moretoread().and.left(v_line,1)<>'['
         v_line:=alltrim(ofile:readline())
          if !empty2(v_line)
            vrachtk->(dbappend())
            vrachtk->deartnr:=upper(left(v_line,14))
          endif
        enddo
      endif
    enddo
  endif
  oFile:Close()
endif

if file("invosendagain.txt")
  ofile := tfileread():new("invosendagain.txt")
  ofile:open()
  if ofile:error()
    qout( ofile:errormsg( "fileread: " ) )
  else
    while ofile:moretoread()
      v_line:=ofile:readline()
      if invoicesend->(dbseek(padr(left(v_line,25),25)))
        invoicesend->(dbdelete())
      endif
    end while
  endif
  ofile:close()
  ferase("invosendagain.txt")
  dbselectarea("invoicesend")
  pack
endif


makedir("outbox")
farray:=directory(v_invmap+"\facturen.xml")
arlen:=len(farray)
v_snr:=1
if arlen>0
  makedir(v_invmap+"\archief")
  makedir(v_invmap+"\archief\"+v_vandaag)
  for x=1 to arlen
    v_file:=farray[x,F_NAME]
    v_snr:=readinv(v_invmap,v_file,v_snr,v_del)
  next
endif

f247fkop->(dbgotop())
do while !f247fkop->(eof())
  if f247freg->(dbseek(f247fkop->s_nr))
    do while !f247freg->(eof()).and.f247freg->s_nr=f247fkop->s_nr
      if vrachtk->(dbseek(padr(upper(f247freg->deartnr),14)))
          f247fkop->vrachtk+=f247freg->bedrag
          f247fkop->vrachtkbtw:=ltrim(str(f247freg->btw))
          f247fkop->netbed:=f247fkop->netbed-f247freg->bedrag
          f247freg->(dbdelete())
      endif
      do case
      case  f247freg->nettoprijs<>f247freg->prijs
        if f247fkop->f_eancode="8712423022867"
          f247freg->prijs:=f247freg->nettoprijs
          f247freg->nettoprijs:=0
        endif
      case f247fkop->branche="OBI"
      otherwise
        f247freg->nettoprijs:=0
        f247freg->brutoprijs:=0
      endcase
      if f247fkop->f_eancode<>"8717263900603"
        if f247fkop->branche<>"MRK"
          f247freg->deuac:=ltrim(str(val(f247freg->deuac),15,0))
        endif
      endif
      if empty2(f247freg->deuac).or.val(f247freg->deuac)=0.or.f247freg->faantal=0.or.f247freg->bedrag=0
        if !vrachtk->(dbseek(f247freg->deartnr))
          f247freg->(dbdelete())
        endif
      endif
      f247freg->(dbskip())
    enddo
  endif
  if empty2(f247fkop->f_eancode)
    f247fkop->(dbdelete())
  endif
  if !is_numeriek(f247fkop->a_eancode)
    f247fkop->(dbdelete())
  endif
  //if !is_numeriek(f247fkop->k_ordernr)
  //  f247fkop->(dbdelete())
  //endif
  if empty2(f247fkop->afl_datum)
    if !empty2(f247fkop->dqdtm171)
      f247fkop->afl_datum:=f247fkop->dqdtm171
    else
      f247fkop->afl_datum:="FOUT"
    endif
  endif
  if invoicesend->(dbseek(f247fkop->fakt_num))
    f247fkop->(dbdelete())
  else
    invoicesend->(dbappend())
    invoicesend->fnum:=f247fkop->fakt_num
  endif
  if !f247freg->(dbseek(f247fkop->s_nr))
    f247fkop->(dbdelete())
  endif
  f247fkop->(dbskip())
enddo

close all
run("247invoiceuit.exe pdf")
RECOVER USING objLocal
END
ERRORBLOCK(bLastHandler)
return(nil)

function readinv(v_invmap,bestand,v_snr,v_del)
local v_at1,v_at2,v_afz:="",v_afznaam:="",v_gead:="",v_knaam:="",v_testf:="",v_branche:="",v_line:="",v_vrkrel:="",ofile:=nil,v_factuurnummer:=""
if file(v_invmap+"\"+bestand)
  set console off
  ofile:=tfileread():new(v_invmap+chr(92)+bestand)
  ofile:open()
  if ofile:error()
    qout( ofile:errormsg( "fileread: " ) )
  else
    while ofile:moretoread()
      v_line:=alltrim(ofile:readline())
      if xmlveld(v_line, "Factuurnummer", @v_waarde)
        if !f247fkop->(dbseek(padr(v_waarde,25)))
          f247fkop->(dbappend())
          f247fkop->s_nr:=padl(ltrim(str(v_snr,5,0)),5,'0')
          v_snr++
          f247fkop->suvat:=v_btwnr
          f247fkop->fakt_num:=v_waarde
          f247fkop->f_soort:="380"
          f247fkop->cux:="EUR"
          f247fkop->sunaam1:="Peacock Garden Support"
          f247fkop->suadres1:=""
          f247fkop->suplaats:=""
          f247fkop->supc:=""
          f247fkop->suland:="NL"
          f247fkop->afz_ean:=v_sugln
          f247fkop->s_eancode:=v_sugln
          f247fkop->branche:="DHZ"
          f247fkop->suvat:=v_btwnr
          v_factuurnummer:=v_waarde
        endif
      endif
      if xmlveld(v_line, "Debiteurnaam", @v_waarde)
        aSpatie:=hb_atokens(v_waarde,' ')
        if len(aSpatie)>0
          f247fkop->ivnaam1:=aSpatie[1]
        else
          f247fkop->ivnaam1:=v_waarde
        endif
      endif
      if xmlveld(v_line, "Invoice_discount", @v_waarde)
        if v_waarde<>"0"
        endif
        f247fkop->btkortbd:=val(strtran(v_waarde,",", ""))
      endif
      if xmlveld(v_line, "Factuurconversie", @v_waarde)
        f247fkop->branche:=upper(alltrim(v_waarde))
      endif
      if xmlveld(v_line, "__Invoice_discount", @v_waarde)
        f247fkop->btkortperc:=v_waarde
      endif
      if xmlveld(v_line, "VAT_Number", @v_waarde)
        f247fkop->ivvat:=v_waarde
      endif
      if xmlveld(v_line, "Pakbon_Toegezegde_leverdatum_regel__JJJJMMDD_", @v_waarde)
        f247fkop->afl_datum:=v_waarde
        f247fkop->dtm69:=v_waarde
      endif
      if xmlveld(v_line, "Bijbehorende_pakbon", @v_waarde)
        f247fkop->pakbonnr:=v_waarde
      endif
      if xmlveld(v_line,"Datum__JJJJMMDD_", @v_waarde)
        f247fkop->dqdtm171:=v_waarde
        f247fkop->dtm171:=v_waarde
      endif
      if xmlveld(v_line,"PakbonDatum", @v_waarde)
        f247fkop->dqdtm171:=v_waarde
      endif
      if xmlveld(v_line, "Factuurdatum", @v_waarde)
        f247fkop->fakt_datum:=strtran(left(v_waarde,10),"-","")
      endif
      if xmlveld(v_line, "Werkelijke_afleverdatum", @v_waarde)
        f247fkop->afl_datum:=v_waarde
      endif
      if xmlveld(v_line, "Referentie_verkooprelatie", @v_waarde)
        f247fkop->k_ordernr:=v_waarde
      endif
      if xmlveld(v_line, "Required_delivery_date", @v_waarde)
        f247fkop->vndtm171:=strtran(v_waarde,'-','')
      endif
      if xmlveld(v_line, "Totaal_bedrag_excl.", @v_waarde)
        f247fkop->netbed:=val(strtran(v_waarde,',','.'))
      endif
      if xmlveld(v_line, "Factuurtotaal", @v_waarde)
        f247fkop->brutbed:=val(strtran(v_waarde,',','.'))
        if f247fkop->brutbed<0
          f247fkop->f_soort:="384"
        else
          f247fkop->f_soort:="380"
        endif
      endif
      if xmlveld(v_line, "Factuurkorting", @v_waarde)
        f247fkop->fkortbd:=val(strtran(v_waarde,',','.'))
      endif
      if xmlveld(v_line, "Bedrag_BTW", @v_waarde)
        f247fkop->btwbed:=val(strtran(v_waarde,',','.'))
      endif
      if xmlveld(v_line, "Bedrag_grondslag__Nul_", @v_waarde)
        f247fkop->btwnul:=val(strtran(v_waarde,',','.'))
      endif
      if xmlveld(v_line, "BTW_percentage__Laag_", @v_waarde)
        f247fkop->btwlperc:=v_waarde
      endif
      if xmlveld(v_line, "Bedrag_grondslag__Laag_", @v_waarde)
        f247fkop->btwlaag:=val(strtran(v_waarde,',','.'))
      endif
      if xmlveld(v_line, "Bedrag_BTW__Laag_", @v_waarde)
        f247fkop->laagbed:=val(strtran(v_waarde,',','.'))
      endif
      if xmlveld(v_line, "BTW_percentage__Hoog_", @v_waarde)
        f247fkop->btwhperc:=alltrim(strtran(v_waarde,',','.'))
      endif
      if xmlveld(v_line, "Bedrag_grondslag__Hoog_", @v_waarde)
        f247fkop->btwhoog:=val(strtran(v_waarde,',','.'))
      endif
      if xmlveld(v_line, "Bedrag_BTW__Hoog_", @v_waarde)
        f247fkop->hoogbed:=val(strtran(v_waarde,',','.'))
      endif
      if xmlveld(v_line, "GLN-DP-Delivery", @v_waarde)
         f247fkop->a_eancode:=strtran(v_waarde," ","")
      endif
      if xmlveld(v_line, "GLN-UC-Eindbestemmimng", @v_waarde)
         f247fkop->uc_eancode:=strtran(v_waarde," ","")
      endif
      if xmlveld(v_line, "GLNBY_Afnemer", @v_waarde)
         f247fkop->b_eancode:=strtran(v_waarde," ","")
      endif
      if xmlveld(v_line, "NADIV", @v_waarde)
         f247fkop->i_eancode:=strtran(v_waarde," ","")
      endif
      if xmlveld(v_line, "GLNUNB", @v_waarde)
         f247fkop->f_eancode:=strtran(v_waarde," ","")
         if f247fkop->f_eancode="8711146000015"
           f247fkop->k_ordernr:="WEBORDER"
         endif
      endif
      if xmlveld(v_line, "Factuur_Test", @v_waarde)
        if v_waarde="true"
           f247fkop->testf:="J"
        endif
      endif
  //end header
  //start lines
      if xmlveld(v_line, "Itemcode", @v_waarde)
        f247freg->(dbappend())
        f247freg->s_nr:=f247fkop->s_nr
        f247freg->deartnr:=v_waarde
      endif
      if xmlveld(v_line, "Barcode", @v_waarde)
        f247freg->deuac:=v_waarde
        if f247fkop->branche="MRK"
          f247freg->deuac:=padl(trim(v_waarde),13,'0')
        endif
      endif
      if xmlveld(v_line, "Omschrijving", @v_waarde)
        //if f247fkop->branche<>"DHZ"
          f247freg->artoms:=upper(strtran(strtran(strtran(strtran(v_waarde,"'",' '),"+"," "),"?"," "),":"," "))
          f247freg->artoms:=killsign(f247freg->artoms)
        //endif
      endif

      if xmlveld(v_line, "Aantal_eenheden", @v_waarde)
        f247freg->aantal:=val(v_waarde)
        f247freg->faantal:=val(v_waarde)
      endif

     //*     f247freg->unitmea:="PCE"

      if xmlveld(v_line, "Regelbedrag", @v_waarde)
        f247freg->bedrag:=round(val(strtran(v_waarde,',','.')),2)
      endif
      if xmlveld(v_line, "Prijs_per_eenheid", @v_waarde)
        f247freg->prijs:=round(val(strtran(v_waarde,',','.')),4)
        f247freg->brutoprijs:=f247freg->prijs
      endif
      if xmlveld(v_line, "Nettoprijs", @v_waarde)
        f247freg->nettoprijs:=round(val(strtran(v_waarde,",",".")),4)
      endif
      if xmlveld(v_line, "BTW_percentage", @v_waarde)
        f247freg->btw:=val(strtran(v_waarde,',','.'))
      endif
      if xmlveld(v_line, "Bedrag_regelkorting", @v_waarde)
        f247freg->kortbd:=round(val(strtran(v_waarde,',','.')),4)
      endif
      if xmlveld(v_line, "__Regelkorting", @v_waarde)
        f247freg->kortbd:=val(strtran(v_waarde,',','.'))
      endif
      if xmlveld(v_line, "Btw-identificatienummer", @v_waarde)
        f247fkop->byvat:=v_waarde
      endif
    enddo
    ofile:close()
    v_bakfile:=v_invmap+chr(92)+"archief"+chr(92)+v_vandaag+chr(92)+v_factuurnummer+".XML"
    ferase(v_bakfile)
    frename(v_invmap+chr(92)+bestand,v_bakfile)
  endif
endif
return(v_snr)

function killsign(waarde)
v_len:=len(trim(waarde))
waarde2:=""
for x=1 to v_len
  if asc(substr(waarde,x,1))<48.or.asc(substr(waarde,x,1))>122
    waarde2:=waarde2+" "
  else
    waarde2:=waarde2+substr(waarde,x,1)
  endif
next
return(waarde2)

function xmlveld(v_line, v_tag,  v_waarde )
local v_line2:=upper(v_line), v_len,v_at1:=0,v_at2:=0,v_start:="",v_sluit:=""
  v_start:="<"+v_tag+">"
  v_sluit:="</"+v_tag+">"
  v_len:=len(v_start)
  v_at1:=at(upper(v_start),v_line2)
  if v_at1<>0
    v_at2:=at(upper(v_sluit),v_line2)
    if v_at2<>0
      v_waarde:=alltrim(substr(v_line,v_at1+v_len,v_at2-v_at1-v_len))
      v_waarde:=strtran(v_waarde, '&amp;', '&')
      v_waarde:=strtran(v_waarde, '&AMP;', '&')
      v_waarde:=strtran(v_waarde, '< ![CDATA[', '')
      v_waarde:=strtran(v_waarde, '<![CDATA[', '')
      v_waarde:=alltrim(strtran(v_waarde, ']]>', ''))
    endif
  endif
return(v_at1<>0.and.v_at2<>0)

function s247errorhandler( objLocal)
  local v_file, nHandle, arlen, x, a:={},nActivation:= 1
  set printer off
  set printer to
  set console on
  set printer to ("247ERROR.TXT") additive
  set printer on
  ??REPLICATE("-", 80)+chr(13)+chr(10)
  ??"Error:"+dtoc(date())+" "+time()+" OS: "+os()+ " WORKSTATION: " + netname()+chr(13)+chr(10)
  ??VERSION()+chr(13)+chr(10)
  ??ltrim(str(objLocal:genCode,10,0)) + ':'+ objLocal:subSystem + ' : ' + ltrim(str(objLocal:subCode,10,0))+ ' : '+objLocal:description + ':' + objLocal:filename + ':' + objLocal:operation + ':oscode:'+ltrim(str(objLocal:osCode,10,0))+chr(13)+chr(10)
   DO WHILE !(PROCNAME(nActivation) == "")
        ?? "Called from:", PROCNAME(nActivation) + "(" + LTRIM(STR(PROCLINE(nActivation))) + ")"+chr(13)+chr(10)
        nActivation++
  ENDDO
  *??REPLICATE("-", 80)+chr(13)+chr(10)
  set printer off
  set printer to
  set console off
  BREAK objLocal
RETURN NIL

function empty2(waarde)
return(if(len(alltrim(waarde))=0,.t.,.f.))

function readline(filename)
local regel :="", i, strlen := 0, length := 0, token := "", cbuffer, nhandle

#define f_block      1024

cbuffer := space(f_block)
nhandle := fopen(filename)
if nhandle > -1
   strlen:=f_block
   while strlen > 0
      strlen:=fread(nhandle, @cbuffer, f_block)
      for i := 1 to strlen
        token:=substr(cbuffer, i , 1)
        if token == chr(10)
          pfline->(dbappend())
          v_line:= regel
          regel:=""
        elseif token <> chr(13)
          length++
          regel:=regel+token
        endif
      next
   enddo
   fclose(nhandle)
   strlen:=len(regel)
   if strlen > 0
      pfline->(dbappend())
      v_line:= regel
   endif
elseif ferror() != 0
   ? "file open error:", ferror()
endif
return(nil)

function is_numeriek(waarde)
local v_ret:=.t.,x:=0
  waarde:=alltrim(waarde)
  for x:=1 to len(waarde)
    if asc(substr(waarde,x,1))<48.or.asc(substr(waarde,x,1))>57
      v_ret:=.f.
    endif
  next
return(v_ret)

