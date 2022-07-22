import traceback
import xmltodict
from datetime import datetime
import os
import shutil
import my247

class Invoice:
    def __init__(self, factdat):
        self.DTM = {'137' : factdat}
        self.NAD = {}
        self.RFF = {}
        self.LIN = []

class Invoices:
    def __init__(self, sender, sendercq, recipient, recipientcq):
        self.UNH = {}
        self.sender = sender
        self.sendercq = sendercq
        self.recipient = recipient
        self.recipientcq = recipientcq


def log(regel):
    ''''
    de file lfile moet open zijn voor schrijven
    de regel wordt er naar geschreven, met een datum/tijd stamp ervoor
    '''
    regel = str(datetime.now()) + ' ' + regel
    lfile.write(regel + '\n')
    print(regel)

def inv_uit(xmldata):
    '''

    @param xmldata:
    @return:
    '''
    uitfact = Invoices('8712423036635','14',xmldata['AfasGetConnector']['GetLine'][0]['GLNUNB'], '14')

    for fline in xmldata['AfasGetConnector']['GetLine']:
        if not(fline['Factuurnummer'][-14:] in uitfact.UNH.keys()):
            # nieuwe factuur aanmaken
            uitfact.UNH[fline['Factuurnummer'][-14:]] = Invoice(datetime.strptime(fline['Factuurdatum'],"%Y-%m-%dT%H:%M:%SZ"))
            uitfact.UNH[fline['Factuurnummer'][-14:]].NAD['DP'] = { 'party' : fline['GLN-DP-Delivery'], 'code' : '9'}
            uitfact.UNH[fline['Factuurnummer'][-14:]].NAD['BY'] = { 'party' : fline['GLNBY_Afnemer'], 'code' : '9', 'RFF' : {'VA' : [ fline['Btw-identificatienummer'] ]}}
            uitfact.UNH[fline['Factuurnummer'][-14:]].NAD['IV'] = { 'party' : fline['NADIV'], 'code' : '9'}
            uitfact.UNH[fline['Factuurnummer'][-14:]].NAD['UC'] = { 'party' : fline['GLN-UC-Eindbestemmimng'], 'code' : '9'}
            uitfact.UNH[fline['Factuurnummer'][-14:]].RFF['ON'] = [{'text' : fline['Referentie_verkooprelatie'] }]
            uitfact.UNH[fline['Factuurnummer'][-14:]].RFF['AAK'] = [{'text' : fline['Bijbehorende_pakbon'] }]
#            uitfact.UNH[fline['Factuurnummer'][-14:]]['test'] = fline['Factuur_Test'] == 'true' # binaire logica om hoofdpijn van te krijgen. In een non-test factuur staat false.
                                                                                              # test op == 'false' geeft True, en dat is precies wat we niet willen opslaan.

        # factuur regel toevoegen
        uitfact.UNH[fline['Factuurnummer'][-14:]].LIN.append({'QTY' : {}})
        uitfact.UNH[fline['Factuurnummer'][-14:]].LIN[-1]['QTY']['47'] = float(fline['Aantal']) # In hoeverre moeten we het hier ook in '12' zetten? Ja doen we in de in-mapping
        uitfact.UNH[fline['Factuurnummer'][-14:]].LIN[-1]['QTY']['12'] = float(fline['Aantal'])
        if 'Barcode' in fline.keys():
            uitfact.UNH[fline['Factuurnummer'][-14:]].LIN[-1]['Itemid'] = fline['Barcode']
            uitfact.UNH[fline['Factuurnummer'][-14:]].LIN[-1]['Itemidcode'] = 'EN' # oude code voor SRV = GTIN? Moeten we hier niet 'SRV' invullen? EN = 96A, SRV = 01B
        uitfact.UNH[fline['Factuurnummer'][-14:]].LIN[-1]['IMD'] = fline['Omschrijving']
        uitfact.UNH[fline['Factuurnummer'][-14:]].LIN[-1]['PIA'] = {'SA' : fline['Itemcode']}
        uitfact.UNH[fline['Factuurnummer'][-14:]].LIN[-1]['PRI'] = {'INV' : fline['Prijs_per_eenheid']} # bruto
        uitfact.UNH[fline['Factuurnummer'][-14:]].LIN[-1]['PRI'] = {'AAA' : fline['Nettoprijs']} # Netto
        uitfact.UNH[fline['Factuurnummer'][-14:]].LIN[-1]['MOA'] = {'203': fline['Regelbedrag']}


    print(uitfact)

# START MAIN CODE
# current directory
cwd = os.getcwd()
# directory+naam van het huidige script
spd = os.path.realpath(__file__)
# hou directory over van huidig script
spd,sname = os.path.split(spd)[0],os.path.split(spd)[1]
# haal .py van de scriptnaam af
#sname is nu de kale scriptnaam
sname = sname[0:len(sname)-3]
my247.init_folders(spd)
# configuratiebestand is basisnaam script, in zelfde pad, met extentie .xml
with open(spd + '/' +sname+'.xml', encoding="utf-8") as conff:
    confcont = conff.read()
# content is nu de plat ingelezen textfile
conf = xmltodict.parse(confcont)

lfilename = conf['config']['datapad'] + '/log/'+sname+'.log'
lfile = open(lfilename, "a", encoding="utf-8")
#os.walk zo aanpassen dat die geen submappen maaneemt, of we moeten leren hier geen mappen te maken
for root, dirs, files in os.walk(conf['config']['datapad']+'/inbox'):
    for filename in files:
        log('start processing ' + conf['config']['datapad']+'/inbox/' + filename)
        perror = False
        try:
            with open(spd+'/' + conf['config']['datapad']+'/inbox/'+filename, encoding="utf-8") as data:
                strdata = data.read()
            # content is nu de plat ingelezen textfile
            xmldata = xmltodict.parse(strdata)
            inv_uit(xmldata)

            new_name = conf['config']['datapad'] + '/archive/' + filename
            shutil.move(conf['config']['datapad'] + '/inbox/' + filename, new_name)
        except Exception as e:
            errtxt = traceback.format_exc()
            error = str(e)
            perror = True
        if perror:
            if conf['config']['mailerror'] != 'off':
                my247.mail_error(errtxt, filename, conf)
            log('!!ERROR!! ' + error)
            log(errtxt)
            efile = open(conf['config']['datapad'] + '/error/'+sname+'.err', "a")
            traceback.print_exc(file=efile)
            efile.close()
            new_name = conf['config']['datapad'] + '/error/' + filename
            shutil.move(conf['config']['datapad'] + '/inbox/' + filename, new_name)
            log('!!ERROR!! bestand verplaatst ' + filename + 'naar ' + new_name)
log(sname+' finished')
lfile.close()

