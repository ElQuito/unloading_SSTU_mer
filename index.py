import pyodbc
import json
import base64
import zipfile
import os

connect_db = pyodbc.connect('DRIVER={SQL Server};SERVER=localhost;DATABASE=ADP_transport;Trusted_Connection=yes;')
cursor = connect_db.cursor()
cursor.execute("EXEC [dbo].[integrationSSTU] @date_from = '2016-01-01',@date_to = '2017-01-01';")

rows = [x for x in cursor]
for data_row in rows:

	#здесть хардкод для МЭР, заменяем гуид подразделения
	if data_row.transfer_departmentId == '11427107-8881-44C2-BB2E-29172682DDC7':
		transfer_departmentId = '8d8e02e1-369b-44ad-b46c-959618c68a91'
	else:
		transfer_departmentId = data_row.transfer_departmentId
	#хардкод для МЭР закончился
		
	if data_row.attachment_content is None: 
		attachment_key = "transfer"
		attachment_content = {  "departmentId": transfer_departmentId,	"transferDate": str(data_row.transfer_transferDate),"transferNumber": data_row.transfer_transferNumber}
	else: 
		attachment_key = "attachment"
		attachment_content = { "name": data_row.attachment_name,"content": base64.b64encode(data_row.attachment_content).decode('ascii')}
		
	if data_row.questions_status == 'NotRegistered': 
		questions = [ { "code" : data_row.questions_code,
					"status": data_row.questions_status,
					"incomingDate": str(data_row.questions_incomingDate)
					} ]
					
	if data_row.questions_status == 'InWork': 
		questions = [ { "code" : data_row.questions_code,
					"status": data_row.questions_status,
					"incomingDate": str(data_row.questions_incomingDate),
					"registrationDate" : str(data_row.questions_registrationDate)
					} ]
					
	if data_row.questions_status == 'Transferred': 
		questions = [ { "code" : data_row.questions_code,
					"status": data_row.questions_status,
					"incomingDate": str(data_row.questions_incomingDate),
					"registrationDate" : str(data_row.questions_registrationDate),
					attachment_key : attachment_content
					} ]
					
	if data_row.questions_status == 'Answered': 
		questions = [ { "code" : data_row.questions_code,
					"status": data_row.questions_status,
					"incomingDate": str(data_row.questions_incomingDate),
					"registrationDate" : str(data_row.questions_registrationDate),
					"responseDate" : str(data_row.questions_responseDate),
					attachment_key : attachment_content
					} ]
		
	array = {
		"departmentId" : data_row.departmentId,
		"isDirect" : data_row.isDirect,
		"format" : data_row.format,
		"number" : data_row.number,
		"createDate" : str(data_row.createDate),
		"name" : data_row.name,
		"address" : data_row.address,
		"email" : data_row.email,
		"questions" : questions
	}
	f = open('upload_sstu\\Document_'+ data_row.InstanceID +'.json', 'w',encoding="utf-8")
	f.write(json.dumps(array, ensure_ascii=False))
	f.close()
#добавляем в архив	
z = zipfile.ZipFile('upload_sstu.zip', 'w')        # Создание нового архива
for root, dirs, files in os.walk('upload_sstu'): # Список всех файлов и папок в директории 'выгрузка'
	for file in files:
	   z.write(os.path.join(root,file))         # Создание относительных путей и запись файлов в архив

z.close()
