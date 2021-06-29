import csv
import requests
import json
import pandas as pd
import sys
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication

api_key = 'CHANGEME'
user_data_csv = './team-owner-list.csv' # set this to your desired path or leave the same to generate csv in same directory
api_headers = {'Content-Type': 'application/json','Authorization':'GenieKey ' + api_key}
get_user_url = "https://api.opsgenie.com/v2/users/" # set as https://api.eu.opsgenie.com/v2/users/ if account is in the EU region
expand_params = {'expand': 'contact'}


def build_user_list(api_key, url, api_headers):
    user_list_request = requests.get(url = get_user_url, headers = api_headers)
    user_json = json.loads(user_list_request.text) 
    users = []
    
    for user in user_json['data']:
        if not user['verified'] or user['blocked']:
            users.append(user['username'])

    while 'next' in user_json['paging']:
        next_url = str(user_json['paging']['next'])
        user_list_request = requests.get(url = next_url, headers = api_headers)
        user_json = json.loads(user_list_request.text)    
        for user in user_json['data']:
            if not user['verified'] or user['blocked']:
                users.append(user['username'])
    return users

def get_user_data(users):
    user_dict = {}
    count = len(users)
    print(str(count) + " users left.")
    for u in users:
        user_dict[u] = get_user_details(u)
        count -= 1
        print("User added: " + u + ", " + str(count) + " users left.")
    generate_csv(user_dict)


def get_user_details(username):
    user = {}
    user_request = requests.get(url = get_user_url + username, headers = api_headers, params = expand_params)
    user_data = json.loads(user_request.text)['data']
    user_teams = get_teams(username)
    user_team_admins = get_team_admins(username)
    user_schedules = get_schedules(username)
    user_escalations = get_escalations(username)

    #user_contacts = user_data.get('userContacts')
    #user_email = []
    #user_mobile = []
    #user_sms = []
    #user_voice = []

    #if user_contacts:

        #for u in user_contacts:
            #if u['contactMethod'] == 'email':
                #user_email.append(u['to'])
            #if u['contactMethod'] == 'mobile':
                #user_mobile.append(u['to'])
            #if u['contactMethod'] == 'sms':
                #user_sms.append(u['to'])
            #if u['contactMethod'] == 'voice':
                #user_voice.append(u['to'])

    user['full_name'] = user_data['fullName']
    #user['username'] = user_data['username']
    #user['time_zone'] = user_data['timeZone']
    #user['locale'] = user_data['locale']
    user['verified'] = user_data['verified']
    #user['user_id'] = user_data['id']
    #user['user_role'] = user_data['role']['name']
    #user['user_address'] = user_data['userAddress']
    #user['created_date'] = user_data['createdAt']

    #user['email'] = ', '.join(user_email)
    #user['mobile'] = ', '.join(user_mobile)
    #user['sms'] = ', '.join(user_sms)    
    #user['voice'] = ', '.join(user_voice)
    user['teams'] = ', '.join(user_teams)
    user['team_admins'] = ', '.join(user_team_admins)
    user['schedules'] = ', '.join(user_schedules)
    #user['escalations'] = ', '.join(user_escalations)
    
    return user


def get_teams(username):
    user_teams_request = requests.get(url = get_user_url + username + "/teams", headers = api_headers)
    teams = json.loads(user_teams_request.text)['data']
    teams_list = []
    for t in teams:
        teams_list.append(t['name'])
    return teams_list
    
def get_team_admins(username):
    user_teams_request = requests.get(url = get_user_url + username + "/teams", headers = api_headers)
    teams = json.loads(user_teams_request.text)['data']
    team_admins_list = []
    for i in teams:
        team_admins_request = requests.get(url = "https://api.opsgenie.com/v2/teams/" + i['id'] + "?identiferType=id", headers = api_headers)
        team_admins = json.loads(team_admins_request.text)['data']
        for a in team_admins['members']:
            if a['role'] == "admin":
                team_admins_list.append(a['user']['username'])
    return team_admins_list

def get_schedules(username):
    user_schedules_request = requests.get(url = get_user_url + username + "/schedules" , headers = api_headers)
    schedules = json.loads(user_schedules_request.text)['data']
    schedules_list = []
    for s in schedules:
        schedules_list.append(s['name'])
    return schedules_list

def get_escalations(username):
    user_escalations_request = requests.get(url = get_user_url + username + "/escalations" , headers = api_headers)
    escalations = json.loads(user_escalations_request.text)['data']
    escalations_list = []
    for e in escalations:
        escalations_list.append(e['name'])
    return escalations_list

def generate_csv(user):
    df = pd.DataFrame(user)
    df_transposed = df.transpose()
    df_transposed.to_csv(user_data_csv, sep=',', encoding='utf-8')

#Send Email Start    
def send_email(body_content):
    sender_email = "python@netjets.com"
    receiver_email = "cbates@netjets.com"
    msg = MIMEMultipart()
    msg['Subject'] = '[Email Test]'
    msg['From'] = sender_email
    msg['To'] = receiver_email

    msgText = MIMEText(body_content, 'html')
    msg.attach(msgText)

    # open and read the CSV file in binary
    with open("team-owner-list.csv",'rb') as file:
    # Attach the file with filename to the email
        msg.attach(MIMEApplication(file.read(), Name="team-owner-list.csv"))
    #filename = "team-owner-list.csv"
    #msg.attach(MIMEText(open(filename).read()))

    try:
        with smtplib.SMTP('smtp.netjets.com', 25) as smtpObj:
            smtpObj.ehlo()
            smtpObj.sendmail(sender_email, receiver_email, msg.as_string())
    except Exception as e:
        print(e)
#Send Email End

#html = df.to_html() may be usable if needing to convert array to html

users = build_user_list(api_key, get_user_url, api_headers)
get_user_data(users)
send_email("Hello! <br><br> We have found that the users in the attached document are listed as UNVERIFIED or SUSPENDED/BLOCKED within Opsgenie. One or more of these accounts are in a team you are an ADMIN of. Before we can delete the user from Opsgenie we need to ensure that the accounts are removed from any TEAMS,SCHEDULES, or ESCALATIONS. Please review and remove any accounts that are not using the on-call feature or are no longer here. <br><br> Thanks! ")
