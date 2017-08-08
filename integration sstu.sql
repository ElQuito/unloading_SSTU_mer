
-- =============================================
-- Author:		<Салахутдинов Ильдар>
-- Create date: <26.07.2017>
-- Description:	<Выгрузка ССТУ>
-- =============================================

ALTER procedure [dbo].[integrationSSTU]

@date_from date, -- дата с
@date_to date,  -- дата по

@typeLink uniqueidentifier  = '024C5228-9E3D-427C-AC6B-87ACAFB5D06A', -- указать нужно тип связи во исполнение
@PartnerOrgRF uniqueidentifier  = 'E9CCADC4-F136-44E7-BDFE-62666992401F', -- Указать ID "Управление Президента РФ по работе с обращениями граждан" (указать ID)
@idMedo uniqueidentifier  = '1ABE3338-8616-43FC-BFDB-BC3EC78CCF70', -- доставка МЭДО (указать ID)
@docKind uniqueidentifier  = '1185AA94-1FAF-48FE-B549-CCF911A69C2E', -- вид обращение гражданина (указать ID)
@docKindAnswed uniqueidentifier  = '0402FF48-449A-4198-B19A-565A3A7761F2', -- вид ответ на обращение гражданина (указать ID)
@docKindLetter uniqueidentifier  = '6217612A-7553-43E7-9D5E-519ADB256A77',-- вид исходящее письмо (указать ID)
@RootDep uniqueidentifier = '06056d85-cd49-4907-90ae-9665a1c7d9f7' --  Идентификатор органа, в котором происходит работа над обращением

as
begin
   	set nocount on;

	set transaction isolation level read uncommitted;

	select 
		distinct
		@RootDep as departmentId,
		CardRegistration_DDMSystem.InstanceID,
------------------------------------------------------------------------------------------------------------------------------------------------
		-- проверяем адресатов с типом 1, если количество 1 то true иначе false
		case 
			 (select count(*) 
			 from [dbo].[dvtable_{5A296B39-B9F1-406E-9CBC-1123067923C5}] as CardRegistration_Addressees 
			 where InstanceID = CardRegistration_DDMSystem.InstanceID 
			   and AddresseeType = 1)
		 when 1 then 'true'
		 else 'false' end as 'isDirect' 
------------------------------------------------------------------------------------------------------------------------------------------------
		-- проверяем вид доставки "МЭДО", если есть хотябы один то ставим значение Electronic иначе Other 
		, case (select count(*) 
				from [dbo].[dvtable_{259975CF-9C88-48C1-A9F4-3919BBBE1180}] as CardRegistration_DeliveryTypes
				where InstanceID = CardRegistration_DDMSystem.InstanceID 
				  and DeliveryType = @idMedo) 
			when 0 then 'Other'
			else 'Electronic' end as 'format' 
------------------------------------------------------------------------------------------------------------------------------------------------
-- выводим исходящий номер только для контрагента "Управление Президента РФ по работе с обращениями граждан"
			,isnull(isnull((select OutgoingNumber + ' ' 
			 from [dbo].[dvtable_{5A296B39-B9F1-406E-9CBC-1123067923C5}] as CardRegistration_Addressees 
			where InstanceID = CardRegistration_DDMSystem.InstanceID 
			  and AddresseeType = 1 
			  and PartnerOrg = @PartnerOrgRF for xml path('')), CardRegistration_DDMSystem.RegistrationNumber),CardRegistration_DDMSystem.SystemNumber )
			as 'number' 
------------------------------------------------------------------------------------------------------------------------------------------------
-- выводим дату создания карточки
		,cast(dsid.CreationDateTime as Date) as createDate 
------------------------------------------------------------------------------------------------------------------------------------------------
 -- выводем название корреспондентов, выводим сотрудников если их нету то выводим подразделения(последние добавленные)
		,(select top 1 
			case  
				when  CardRegistration_Addressees.PartnerEmpl is not null
				then isnull(RefPartners_Employees.LastName, '') + ' ' +  isnull(RefPartners_Employees.FirstName, '') + ' ' + isnull(RefPartners_Employees.MiddleName, '') 
				else RefPartners_Companies.Name end 
			from [dbo].[dvtable_{5A296B39-B9F1-406E-9CBC-1123067923C5}] as CardRegistration_Addressees 
			left join [dbo].[dvtable_{1A46BF0F-2D02-4AC9-8866-5ADF245921E8}] as RefPartners_Employees
			on CardRegistration_Addressees.PartnerEmpl = RefPartners_Employees.RowID
			left join [dbo].[dvtable_{C78ABDED-DB1C-4217-AE0D-51A400546923}] as RefPartners_Companies
			on CardRegistration_Addressees.PartnerOrg = RefPartners_Companies.RowID
			where CardRegistration_Addressees.InstanceID = CardRegistration_DDMSystem.InstanceID
			and AddresseeType = 1 
			order by CardRegistration_Addressees.Type, CardRegistration_Addressees.[Order] desc) as 'name'
------------------------------------------------------------------------------------------------------------------------------------------------
-- выводем адреса корреспондентов, выводим сотрудников если их нету то выводим подразделения(последние добавленные)
		,(select top 1 
			case  
				when  CardRegistration_Addressees.PartnerEmpl is not null
				then isnull(RefPartners_Employees.City, ' ') + ' ' + isnull(RefPartners_Employees.Address, ' ')
				else isnull(RefPartners_Addresses.City, ' ') + ' ' + isnull(RefPartners_Addresses.Address, ' ') end 
			from [dbo].[dvtable_{5A296B39-B9F1-406E-9CBC-1123067923C5}] as CardRegistration_Addressees 
			left join [dbo].[dvtable_{1A46BF0F-2D02-4AC9-8866-5ADF245921E8}] as RefPartners_Employees
			on CardRegistration_Addressees.PartnerEmpl = RefPartners_Employees.RowID
			left join [dbo].[dvtable_{C78ABDED-DB1C-4217-AE0D-51A400546923}] as RefPartners_Companies
			on CardRegistration_Addressees.PartnerOrg = RefPartners_Companies.RowID
			left join [dbo].[dvtable_{1DE3032F-1956-4C37-AE14-A29F8B47E0AC}] as RefPartners_Addresses
			on RefPartners_Companies.RowID = RefPartners_Addresses.ParentRowID
			where CardRegistration_Addressees.InstanceID = CardRegistration_DDMSystem.InstanceID
			and AddresseeType = 1 
			order by CardRegistration_Addressees.Type, CardRegistration_Addressees.[Order] desc) as 'address' 
	
------------------------------------------------------------------------------------------------------------------------------------------------
-- выводем email корреспондентов, выводим сотрудников если их нету то выводим подразделения(последние добавленные)
	,(select top 1 
			case  
				when  CardRegistration_Addressees.PartnerEmpl is not null
				then RefPartners_Employees.Email
				else RefPartners_Companies.Email end 
			from [dbo].[dvtable_{5A296B39-B9F1-406E-9CBC-1123067923C5}] as CardRegistration_Addressees 
			left join [dbo].[dvtable_{1A46BF0F-2D02-4AC9-8866-5ADF245921E8}] as RefPartners_Employees
			on CardRegistration_Addressees.PartnerEmpl = RefPartners_Employees.RowID
			left join [dbo].[dvtable_{C78ABDED-DB1C-4217-AE0D-51A400546923}] as RefPartners_Companies
			on CardRegistration_Addressees.PartnerOrg = RefPartners_Companies.RowID
			where CardRegistration_Addressees.InstanceID = CardRegistration_DDMSystem.InstanceID
			and AddresseeType = 1 
			order by CardRegistration_Addressees.Type, CardRegistration_Addressees.[Order] desc) as 'email' 
------------------------------------------------------------------------------------------------------------------------------------------------
		-- выводим последние чётыре символа категории
		,(select top 1  SUBSTRING(RefCategories_Categories.Name, 16, 4)
		from [dbo].[dvtable_{C286C0E6-D876-4C9D-BA89-AC39AFC6C0C4}] as CardRegistration_Categories 
		inner join [dbo].[dvtable_{899C1470-9ADF-4D33-8E69-9944EB44DBE7}] as RefCategories_Categories 
		on RefCategories_Categories.RowID = CardRegistration_Categories.Category
		where CardRegistration_Categories.InstanceID = CardRegistration_DDMSystem.InstanceID) as 'questions_code' 
------------------------------------------------------------------------------------------------------------------------------------------------
		-- выводим состояния			
		,(select 
			case  
			when CardRegistration_System.State = '60EED5C0-3FA2-4E26-AB6A-A0A13729C70B' 
				and CardRegistration_RegistrationData_2.RegistrationDate is null 
			then 'NotRegistered'

			when (CardRegistration_System.State = 'FA27DA56-D0F2-4C85-97AE-98E8149ADB40' 
				or CardRegistration_System.State = 'AE65511D-FE75-40D7-B51D-6554527E692D') 
				and (not exists  (select * from [dbo].[dvtable_{6B8CD1D6-4286-4E9D-B282-5099BEB6F948}] as CardRegistration_LinkedCards
									inner join [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_13
									on CardRegistration_LinkedCards.CardID = CardRegistration_RegistrationData_13.InstanceID
									where CardRegistration_LinkedCards.InstanceID = CardRegistration_System.InstanceID
									and CardRegistration_LinkedCards.LinkType = @typeLink
									and CardRegistration_RegistrationData_13.Kind in (@docKindAnswed,@docKindLetter))
					or 	(select top 1 CardRegistration_System_1.State 
						from [dbo].[dvtable_{BE963903-8360-4020-A2E0-016C74CBFB02}] as CardRegistration_System_1
						inner join [dbo].[dvtable_{6B8CD1D6-4286-4E9D-B282-5099BEB6F948}] as CardRegistration_LinkedCards
						on CardRegistration_System_1.InstanceID = CardRegistration_LinkedCards.CardID
						inner join [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_11
						on CardRegistration_System_1.InstanceID = CardRegistration_RegistrationData_11.InstanceID
						where CardRegistration_LinkedCards.InstanceID = CardRegistration_System.InstanceID 
						and CardRegistration_LinkedCards.LinkType = @typeLink
						and CardRegistration_RegistrationData_11.Kind = @docKindAnswed) 
						not in ('FA27DA56-D0F2-4C85-97AE-98E8149ADB40','AE65511D-FE75-40D7-B51D-6554527E692D' ) 			
						)
			then 'InWork'

			when 
				(select top 1 CardRegistration_System_1.State 
				from [dbo].[dvtable_{BE963903-8360-4020-A2E0-016C74CBFB02}] as CardRegistration_System_1
				inner join [dbo].[dvtable_{6B8CD1D6-4286-4E9D-B282-5099BEB6F948}] as CardRegistration_LinkedCards
				on CardRegistration_System_1.InstanceID = CardRegistration_LinkedCards.CardID
				inner join [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_11
				on CardRegistration_System_1.InstanceID = CardRegistration_RegistrationData_11.InstanceID
				where CardRegistration_LinkedCards.InstanceID = CardRegistration_System.InstanceID 
				and CardRegistration_LinkedCards.LinkType = @typeLink
				and CardRegistration_RegistrationData_11.Kind = @docKindAnswed) 
				in ('FA27DA56-D0F2-4C85-97AE-98E8149ADB40','AE65511D-FE75-40D7-B51D-6554527E692D' ) 
				and
				(select count(*)
				from [dbo].[dvtable_{BE963903-8360-4020-A2E0-016C74CBFB02}] as CardRegistration_System_1
				inner join [dbo].[dvtable_{6B8CD1D6-4286-4E9D-B282-5099BEB6F948}] as CardRegistration_LinkedCards
				on CardRegistration_System_1.InstanceID = CardRegistration_LinkedCards.CardID
				inner join [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_11
				on CardRegistration_System_1.InstanceID = CardRegistration_RegistrationData_11.InstanceID
				where CardRegistration_LinkedCards.InstanceID = CardRegistration_System.InstanceID 
				and CardRegistration_LinkedCards.LinkType = @typeLink
				and CardRegistration_RegistrationData_11.Kind = @docKindLetter
				and CardRegistration_System_1.State in ('FA27DA56-D0F2-4C85-97AE-98E8149ADB40','AE65511D-FE75-40D7-B51D-6554527E692D' ) ) = 0
				
			then 'Answered'

			when 
				(select top 1 CardRegistration_System_1.State 
				from [dbo].[dvtable_{BE963903-8360-4020-A2E0-016C74CBFB02}] as CardRegistration_System_1
				inner join [dbo].[dvtable_{6B8CD1D6-4286-4E9D-B282-5099BEB6F948}] as CardRegistration_LinkedCards
				on CardRegistration_System_1.InstanceID = CardRegistration_LinkedCards.CardID
				inner join [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_11
				on CardRegistration_System_1.InstanceID = CardRegistration_RegistrationData_11.InstanceID
				where CardRegistration_LinkedCards.InstanceID = CardRegistration_System.InstanceID 
				and CardRegistration_LinkedCards.LinkType = @typeLink
				and CardRegistration_RegistrationData_11.Kind = @docKindLetter) 
				in ('FA27DA56-D0F2-4C85-97AE-98E8149ADB40','AE65511D-FE75-40D7-B51D-6554527E692D' ) 
			then 'Transferred' end 

			from [dbo].[dvtable_{BE963903-8360-4020-A2E0-016C74CBFB02}] as CardRegistration_System
			inner join [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_2
			on CardRegistration_System.InstanceID = CardRegistration_RegistrationData_2.InstanceID	
			where CardRegistration_System.InstanceID = CardRegistration_DDMSystem.InstanceID)
			as 'questions_status' 
------------------------------------------------------------------------------------------------------------------------------------------------
		-- выводим дату создания карточки
		,cast(dsid.CreationDateTime as Date) as 'questions_incomingDate' 
------------------------------------------------------------------------------------------------------------------------------------------------
		-- выводим дату регистрации карточки
		,cast (CardRegistration_RegistrationData.RegistrationDate as Date) as 'questions_registrationDate' 
------------------------------------------------------------------------------------------------------------------------------------------------
		-- выводим дату регистрации карточки исх
		, (select top 1 cast (CardRegistration_RegistrationData_1.RegistrationDate as Date) 
				from  [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_1
				inner join [dbo].[dvtable_{6B8CD1D6-4286-4E9D-B282-5099BEB6F948}] as CardRegistration_LinkedCards
				on CardRegistration_RegistrationData_1.InstanceID = CardRegistration_LinkedCards.CardID
				where  CardRegistration_DDMSystem.InstanceID = CardRegistration_LinkedCards.InstanceID 
				and CardRegistration_LinkedCards.LinkType = @typeLink 
				)
		 as 'questions_responseDate' 
------------------------------------------------------------------------------------------------------------------------------------------------

		 , (select case CardRegistration_Properties_3.DisplayValue when 'Меры приняты' then 'true' else 'false' end 
			from [dbo].[dvtable_{DFAB139A-71DD-4858-9946-89275F6D883B}] as CardRegistration_Properties_3
			where CardRegistration_Properties_3.InstanceID = CardRegistration_DDMSystem.InstanceID 
			  and CardRegistration_Properties_3.Name = 'Вид исполнения' ) as 'questions_actionsTaken' 

------------------------------------------------------------------------------------------------------------------------------------------------

			-- имя приложенного файла, выводим топ 1
			,(select top 1  f.Name
			from [dbo].[dvtable_{6B8CD1D6-4286-4E9D-B282-5099BEB6F948}] as CardRegistration_LinkedCards
			inner join  [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_7
			on CardRegistration_RegistrationData_7.InstanceID = CardRegistration_LinkedCards.CardID
			inner join [dbo].[dvtable_{E962AC85-0F53-4439-A1CD-171E46C3EF91}] as FileList_FileReferences
			on CardRegistration_RegistrationData_7.FilesID = FileList_FileReferences.InstanceID
			inner join [dbo].[dvtable_{B4562DF8-AF19-4D0F-85CA-53A311354D39}] as CardFile_MainInfo
			on FileList_FileReferences.CardFileID = CardFile_MainInfo.InstanceID
			inner join [dbo].[dvtable_{F831372E-8A76-4ABC-AF15-D86DC5FFBE12}] as VersionedFileCard_Versions
			on CardFile_MainInfo.FileID = VersionedFileCard_Versions.InstanceID
			inner join [dbo].[dvsys_files] f
			on f.FileID = VersionedFileCard_Versions.FileID
			where  CardRegistration_DDMSystem.InstanceID = CardRegistration_LinkedCards.InstanceID 
			and CardRegistration_LinkedCards.LinkType = @typeLink 
			and CardRegistration_RegistrationData_7.Kind = @docKindAnswed
			order by  f.Timestamp desc) as 'attachment_name' 

------------------------------------------------------------------------------------------------------------------------------------------------
		-- выводим бинарник файла, выводим топ 1
			,(select top 1  b.Data
			from [dbo].[dvtable_{6B8CD1D6-4286-4E9D-B282-5099BEB6F948}] as CardRegistration_LinkedCards
			inner join  [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_8
			on CardRegistration_RegistrationData_8.InstanceID = CardRegistration_LinkedCards.CardID
			inner join [dbo].[dvtable_{E962AC85-0F53-4439-A1CD-171E46C3EF91}] as FileList_FileReferences
			on CardRegistration_RegistrationData_8.FilesID = FileList_FileReferences.InstanceID
			inner join [dbo].[dvtable_{B4562DF8-AF19-4D0F-85CA-53A311354D39}] as CardFile_MainInfo
			on FileList_FileReferences.CardFileID = CardFile_MainInfo.InstanceID
			inner join [dbo].[dvtable_{F831372E-8A76-4ABC-AF15-D86DC5FFBE12}] as VersionedFileCard_Versions
			on CardFile_MainInfo.FileID = VersionedFileCard_Versions.InstanceID
			inner join [dbo].[dvsys_files] f
			on f.FileID = VersionedFileCard_Versions.FileID
			inner join [dbo].[dvsys_binaries] b 
			on f.BinaryID = b.ID
			where  CardRegistration_DDMSystem.InstanceID = CardRegistration_LinkedCards.InstanceID 
			and CardRegistration_LinkedCards.LinkType = @typeLink 
			and CardRegistration_RegistrationData_8.Kind = @docKindAnswed
			order by  f.Timestamp desc) as 'attachment_content' 
------------------------------------------------------------------------------------------------------------------------------------------------
		,(select top 1 CardRegistration_Addressees_3.PartnerOrg
			from [dbo].[dvtable_{5A296B39-B9F1-406E-9CBC-1123067923C5}] as CardRegistration_Addressees_3
			inner join [dbo].[dvtable_{6B8CD1D6-4286-4E9D-B282-5099BEB6F948}] as CardRegistration_LinkedCards
			on CardRegistration_Addressees_3.InstanceID = CardRegistration_LinkedCards.CardID
			inner join [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_13
			on CardRegistration_Addressees_3.InstanceID = CardRegistration_RegistrationData_13.InstanceID
			inner join [dbo].[dvtable_{BE963903-8360-4020-A2E0-016C74CBFB02}] as CardRegistration_System_6
			on CardRegistration_Addressees_3.InstanceID = CardRegistration_System_6.InstanceID
			where CardRegistration_LinkedCards.InstanceID = CardRegistration_DDMSystem.InstanceID 
			and CardRegistration_LinkedCards.LinkType = @typeLink  
			and CardRegistration_Addressees_3.AddresseeType = 0 
			and CardRegistration_Addressees_3.Type =3
			and CardRegistration_RegistrationData_13.Kind = @docKindLetter
			and CardRegistration_System_6.State in ('FA27DA56-D0F2-4C85-97AE-98E8149ADB40','AE65511D-FE75-40D7-B51D-6554527E692D' )
			order by CardRegistration_Addressees_3.[Order] desc)

   		as  'transfer_departmentId'
------------------------------------------------------------------------------------------------------------------------------------------------
		,(select top 1 cast(CardRegistration_RegistrationData_5.RegistrationDate as Date)
			from [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_5
			inner join [dbo].[dvtable_{6B8CD1D6-4286-4E9D-B282-5099BEB6F948}] as CardRegistration_LinkedCards
			on CardRegistration_RegistrationData_5.InstanceID = CardRegistration_LinkedCards.CardID
			inner join [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_14
			on CardRegistration_RegistrationData_5.InstanceID = CardRegistration_RegistrationData_14.InstanceID
			inner join [dbo].[dvtable_{BE963903-8360-4020-A2E0-016C74CBFB02}] as CardRegistration_System_7
			on CardRegistration_RegistrationData_5.InstanceID = CardRegistration_System_7.InstanceID
			where CardRegistration_LinkedCards.InstanceID = CardRegistration_DDMSystem.InstanceID 
			and CardRegistration_LinkedCards.LinkType = @typeLink  
			and CardRegistration_RegistrationData_14.Kind = @docKindLetter
			and CardRegistration_System_7.State in ('FA27DA56-D0F2-4C85-97AE-98E8149ADB40','AE65511D-FE75-40D7-B51D-6554527E692D' ) 
			)

   		as  'transfer_transferDate'
------------------------------------------------------------------------------------------------------------------------------------------------
		,(select top 1 CardRegistration_DDMSystem_6.RegistrationNumber
			from [dbo].[dvtable_{88E884FD-5FD2-4F8F-A8CF-53CB50A8C085}] as CardRegistration_DDMSystem_6
			inner join [dbo].[dvtable_{6B8CD1D6-4286-4E9D-B282-5099BEB6F948}] as CardRegistration_LinkedCards
			on CardRegistration_DDMSystem_6.InstanceID = CardRegistration_LinkedCards.CardID
			inner join [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData_15
			on CardRegistration_DDMSystem_6.InstanceID = CardRegistration_RegistrationData_15.InstanceID
			inner join [dbo].[dvtable_{BE963903-8360-4020-A2E0-016C74CBFB02}] as CardRegistration_System_8
			on CardRegistration_DDMSystem_6.InstanceID = CardRegistration_System_8.InstanceID
			where CardRegistration_LinkedCards.InstanceID = CardRegistration_DDMSystem.InstanceID 
			and CardRegistration_LinkedCards.LinkType = @typeLink  
			and CardRegistration_RegistrationData_15.Kind = @docKindLetter
			and CardRegistration_System_8.State in ('FA27DA56-D0F2-4C85-97AE-98E8149ADB40','AE65511D-FE75-40D7-B51D-6554527E692D' ) 
			)

   		as  'transfer_transferNumber'
------------------------------------------------------------------------------------------------------------------------------------------------
	from [dbo].[dvtable_{88E884FD-5FD2-4F8F-A8CF-53CB50A8C085}] as CardRegistration_DDMSystem  
	inner join dvsys_instances_date dsid on dsid.InstanceID = CardRegistration_DDMSystem.InstanceID
	inner join [dbo].[dvtable_{F9D3EF11-A060-415A-BE69-DA9EFD3CA436}] as CardRegistration_RegistrationData
	on CardRegistration_DDMSystem.InstanceID = CardRegistration_RegistrationData.InstanceID 
	inner join [dbo].[dvtable_{BE963903-8360-4020-A2E0-016C74CBFB02}] as CardRegistration_System_0
	on CardRegistration_DDMSystem.InstanceID = CardRegistration_System_0.InstanceID
	where CardRegistration_DDMSystem.Type = 0
	and dsid.CreationDateTime > @date_from and dsid.CreationDateTime < @date_to 
	and CardRegistration_RegistrationData.Kind = @docKind
	and CardRegistration_System_0.State not in ('4794A8E9-FE2C-45D4-A602-38DA1F64A8C0','0AA3FE31-674A-4545-B680-A330A2DB06C1'); 

end

