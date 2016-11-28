public with sharing class GetRecordsWithJsController {

    public List<String> tableList { get; set; }

    public GetRecordsWithJsController() {
        tableList = new List<String>();
        tableList.add('--None--');
        for (Schema.SObjectType objectType : Schema.getGlobalDescribe().values()) {
            tableList.add(String.valueOf(objectType));
        }
    }

    @RemoteAction
    public static List<String> getAllFields(String tableName) {
        List<String> fieldsAll = new List<String>();

        if (String.isNotBlank(tableName) && (tableName != '--None--')) {
            Map<String,Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(tableName).getDescribe().fields.getMap();
            for (Schema.SObjectField field : fieldMap.Values()) {
                String fieldName = String.valueOf(field);
                Schema.SObjectField schemaField = fieldMap.get(fieldName);
                Schema.DisplayType fldType = schemaField.getDescribe().getType();
                if (String.valueOf(fldType) == 'ADDRESS') {
                    continue;
                } 
                else {
                    fieldsAll.add(fieldName);
                }
            }
        }

        return fieldsAll;
    }

    @RemoteAction
    public static List<Object> runQuery(String tableName, List<String> tableFields) {
        //include field 'ID' for any query
        List<String> fields = new List<String>();
        if (tableFields[0] != 'Id') {
            fields.add('Id');
            fields.addAll(tableFields);
        } 
        else {
            fields.addAll(tableFields);    
        }

        //create query
        String query = 'SELECT ';
        for (String field : fields) {
            query += field + ',';
        }
        query = query.substringBeforeLast(',') + ' FROM ' + tableName;

        //get all records
        List<SObject> records = new List<SObject>();
        records = Database.query(query);
        Map<String,Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(tableName).getDescribe().fields.getMap();
        Map<String,Schema.DisplayType> fieldTypeMap = new Map<String,Schema.DisplayType>();
        for (String field : fields) {
            Schema.SObjectField schemaField = fieldMap.get(field.trim());
            Schema.DisplayType fldType = schemaField.getDescribe().getType();
            fieldTypeMap.put(field, fldType);
        }

        //create map for edit permission
        List <FieldPermissions> fieldPermissionsList = [
            SELECT Field, PermissionsEdit
            FROM FieldPermissions
            WHERE SobjectType = :tableName
        ];
        Map<String,Boolean> editPermissionsMap = new Map<String,Boolean>();
        for (FieldPermissions fieldpermission : fieldPermissionsList) {
            String currentFieldName = fieldpermission.Field.removeStart(tableName + '.').toUpperCase();
            editPermissionsMap.put(currentFieldName, fieldpermission.PermissionsEdit);
        }

        //create result data object
        List<ResultObject> resultObjects = new List<ResultObject>();
        for (sObject record : records) {
            ResultObject resultObject = new ResultObject(fieldTypeMap, record, editPermissionsMap);
            resultObjects.add(resultObject);
        }
        return resultObjects;
    }

    public class ResultObject {        
        public List<StructureData> fieldsList { get; set; }   

        public ResultObject(Map<String,Schema.DisplayType> fields, sObject record, Map<String,Boolean> editPermissionsMap) {
            this.fieldsList = new List<StructureData>(); 
            for (String fieldName : fields.keySet()) {
                String fieldType = String.valueOf(fields.get(fieldName));               
                Boolean isEdit =  editPermissionsMap.get(fieldName.toUpperCase());
                isEdit = (isEdit == null) ? false : isEdit;
                StructureData structureData = new StructureData(fieldName, record.get(fieldName), fieldType, isEdit);
                this.fieldsList.add(structureData);                     
            }
        }
    }

    class StructureData {
        String fieldName { get; set; }
        Object fieldValue { get; set; }
        String fieldType { get; set; }
        Boolean isEdit { get; set; }

        StructureData(String fieldName, Object fieldValue, String fieldType, Boolean isEdit) {
            this.fieldName = fieldName;
            this.fieldValue = fieldValue;
            this.fieldType = fieldType;
            this.isEdit = isEdit;
        }           
    }

    @RemoteAction
    public static void saveListObjects(List<String> records, String tableName) {
        //created header list
        String headerRow = records[0].replace('[', ' ').replace(']', ' ');
        List<String> headerList = new List<String>();
        headerList = headerRow.split(',');

        Map<String,Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(tableName).getDescribe().fields.getMap();
        Map<String,Schema.DisplayType> headerMap = new Map<String,Schema.DisplayType>(); 
        for (String header : headerList) {
            Schema.SObjectField field = fieldMap.get(header.trim());
            Schema.DisplayType fldType = field.getDescribe().getType();
            headerMap.put(header.trim(), fldType);
        }


        List<sObject> sObjects = new List<sObject>();
        for (Integer rowNumber = 1; rowNumber < records.size(); rowNumber++) {
            String row = records[rowNumber].replace('[', ' ').replace(']', ' ');
            List<String> fieldNames = new List<String>();
            fieldNames = row.split(',');
            sObject sObj = Schema.getGlobalDescribe().get(tableName).newSObject();          
            for (Integer fieldNumber = 0; fieldNumber < fieldNames.size(); fieldNumber++) {
                String curType = String.valueOf(headerMap.get(headerList[fieldNumber].trim()));                
                Object fieldValue = fieldNames[fieldNumber].trim();
                if (fieldValue != null) {
                    try {
                        if (curType == 'DOUBLE') {
                            fieldValue = Double.valueOf(fieldNames[fieldNumber].trim());
                        }
                        else if (curType == 'DATE') {
                            List<String> dateList = fieldNames[fieldNumber].trim().split('/');
                            String currentDate = dateList[2] + '-' + dateList[1] + '-' + dateList[0];
                            fieldValue = Date.valueOf(currentDate);
                        }
                        else if (curType == 'INTEGER') {
                            fieldValue = Integer.valueOf(fieldNames[fieldNumber].trim());
                        }
                        else if (curType == 'BOOLEAN') {
                            fieldValue = Boolean.valueOf(fieldNames[fieldNumber].trim());
                        }
                    }
                    catch(Exception e) {
                        fieldValue = null;
                    }
                }
                sObj.put(headerList[fieldNumber].trim(), fieldValue);
            }
            sObjects.add(sObj);
        }
        update(sObjects);
    }    
    

}