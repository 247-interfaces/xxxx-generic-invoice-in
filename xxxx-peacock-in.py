import traceback
import xmltodict
from datetime import datetime
import os
import shutil
import my247

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
    pass
    uitfact = {}
    for fline in xmldata['AfasGetConnector']['GetLine']:
        if fline['Factuurnummer'] in uitfact.keys():
            # factuur aanvullen met nieuwe regel
            pass
        else:
            uitfact[fline['Factuurnummer']] = {'DTM' : {}, 'NAD' : {}, 'LIN': []} # nieuwe factuur toevoegen
            uitfact[fline['Factuurnummer']]['DTM']['137'] = fline['Factuurdatum']
        uitfact[fline['Factuurnummer']]['LIN'].append({'QTY' : {}})
        uitfact[fline['Factuurnummer']]['LIN'][-1]['Omschrijving'] = fline['Omschrijving']
        uitfact[fline['Factuurnummer']]['LIN'][-1]['QTY']['47'] = fline['Aantal']

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

