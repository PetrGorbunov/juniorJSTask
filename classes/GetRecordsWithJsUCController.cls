public with sharing class GetRecordsWithJsUCController {

    private static final String TABLE_NAME_NONE = '--NONE--';
    //private List<String> tableNames { get; set; }

    //public GetRecordsWithJsUCController() {
    //    //tableNames = getTableName();
    //    //System.debug('tableNames=' + tableNames);
    //}

    //private List<String> getTableName() {
    //    List<String> tableNames = new List<String>();
    //    tableNames.add(TABLE_NAME_NONE);
    //    for (Schema.SObjectType objectType : Schema.getGlobalDescribe().values()) {
    //        tableNames.add(String.valueOf(objectType));
    //    }
    //    return tableNames;
    //}

    @RemoteAction
    public static List<String> getTableNames() {
        List<String> tableNames = new List<String>();
        tableNames.add(TABLE_NAME_NONE);
        for (Schema.SObjectType objectType : Schema.getGlobalDescribe().values()) {
            tableNames.add(String.valueOf(objectType));
        }
        tableNames.sort();

        //String result = JSON.serialize(tableNames);

        return tableNames;
    }

    @RemoteAction
    public static List<String> getFields(String tableName) {
        List<String> fieldsAll = new List<String>();

        if (String.isNotBlank(tableName) && (tableName != TABLE_NAME_NONE)) {
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
    public static List<Object> runQuery(String tableName, List<String> fields, String sortField, Boolean isASC) {
        //include field 'ID' for any query
        //List<String> fields = new List<String>();
        //if (tableFields[0] != 'Id') {
        //    fields.add('Id');
        //    fields.addAll(tableFields);
        //} 
        //else {
        //    fields.addAll(tableFields);    
        //}

        //create query
        String direction = (isASC) ? 'ASC' : 'DESC';

        String query = 'SELECT ';
        for (String field : fields) {
            query += field + ',';
        }
        query = query.substringBeforeLast(',') + ' FROM ' + tableName + ' ORDER BY ' + sortField + ' ' + direction;

        //get all records
        List<SObject> records = new List<SObject>();
        records = Database.query(query);
        Map<String,Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(tableName).getDescribe().fields.getMap();
        Map<String,Schema.DisplayType> fieldTypeMap = new Map<String,Schema.DisplayType>();

        Map<String, List<String>> piclistValuesMap = new Map<String, List<String>>();

        for (String field : fields) {
            Schema.SObjectField schemaField = fieldMap.get(field.trim());
            Schema.DisplayType fldType = schemaField.getDescribe().getType();
            System.debug(field + ':' + String.valueOf(fldType));

            if (String.valueOf(fldType) == 'PICKLIST' || String.valueOf(fldType) == 'MULTIPICKLIST') {
                System.debug('SPARTA:PICKLIST');
                List<Schema.PicklistEntry> picklistEntries = fieldMap.get(field).getDescribe().getPickListValues();
                List<String> picklistValues = new List<String>(); 
                for (Schema.PicklistEntry picklistEntry : picklistEntries ) {
                    picklistValues.add(picklistEntry.getValue());
                }
                piclistValuesMap.put(field, picklistValues);
            }
            fieldTypeMap.put(field, fldType);
        }
        System.debug('piclistValuesMap=' + piclistValuesMap);
        //get picklist values
        //List<Schema.PicklistEntry> pick_list_values = field_map.get(Field_name).getDescribe().getPickListValues();

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
            ResultObject resultObject = new ResultObject(fieldTypeMap, record, editPermissionsMap, piclistValuesMap);
            resultObjects.add(resultObject);
        }
        return resultObjects;
    }

    public class ResultObject {        
        public List<StructureData> fieldsList { get; set; }   

        public ResultObject(Map<String,Schema.DisplayType> fields, sObject record, Map<String,Boolean> editPermissionsMap, Map<String, List<String>> piclistValuesMap) {
            this.fieldsList = new List<StructureData>(); 
            for (String fieldName : fields.keySet()) {
                String fieldType = String.valueOf(fields.get(fieldName));               
                Boolean isEdit =  editPermissionsMap.get(fieldName.toUpperCase());
                isEdit = (isEdit == null) ? false : isEdit;
                List<String> picklistValues = piclistValuesMap.get(fieldName);
                StructureData structureData = new StructureData(fieldName, record.get(fieldName), fieldType, isEdit, picklistValues);
                this.fieldsList.add(structureData);                     
            }
        }
    }

    class StructureData {
        String fieldName { get; set; }
        Object fieldValue { get; set; }
        String fieldType { get; set; }
        List<String> picklistValues { get; set; }

        Boolean isEdit { get; set; }

        StructureData(String fieldName, Object fieldValue, String fieldType, Boolean isEdit, List<String> picklistValues) {
            this.fieldName = fieldName;
            this.fieldValue = fieldValue;
            this.fieldType = fieldType;
            this.isEdit = isEdit;
            if (picklistValues != null) {
                this.picklistValues = picklistValues;
            }
        }           
    }

    static Object getAdduceValue(String fieldType, String value) {
        Object resultValue = value;
        if (resultValue != null) {
            try {
                if (fieldType == 'DOUBLE') {
                    resultValue = Double.valueOf(value);
                }
                else if (fieldType == 'DATE') {
                    System.debug('getAdduceValue():value=' + value);
                    resultValue = Date.valueOf(value);
                    //List<String> dateList = fieldNames[fieldNumber].trim().split('/');
                    //String currentDate = dateList[2] + '-' + dateList[1] + '-' + dateList[0];
                    //fieldValue = Date.valueOf(currentDate);
                }
                else if (fieldType == 'DATETIME') {
                    System.debug('getAdduceValue():value=' + value);
                    resultValue = Date.valueOf(value);
                    //List<String> dateList = fieldNames[fieldNumber].trim().split('/');
                    //String currentDate = dateList[2] + '-' + dateList[1] + '-' + dateList[0];
                    //fieldValue = Date.valueOf(currentDate);
                }
                else if (fieldType == 'INTEGER') {
                    resultValue = Integer.valueOf(value);
                }
                else if (fieldType == 'BOOLEAN') {
                    resultValue = Boolean.valueOf(value);
                }
                else if (fieldType == 'PICKLIST') {

                }
            }
            catch(Exception e) {
                resultValue = null;
            }
        }
        return resultValue;
    }

    @RemoteAction
    public static void saveListObjects(String rec, String tableName) {
        //created header list
        System.debug('rec=' + rec);
        List<List<String>> recordsList = (List<List<String>>)System.JSON.deserialize(rec, List<List<String>>.class);
        System.debug('recordsList=' + recordsList);
        
        Map<String,Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(tableName).getDescribe().fields.getMap();
        Map<String,Schema.DisplayType> headerMap = new Map<String,Schema.DisplayType>(); 
        for (String header : recordsList[0]) {
            Schema.SObjectField field = fieldMap.get(header.trim());
            Schema.DisplayType fldType = field.getDescribe().getType();
            headerMap.put(header.trim(), fldType);
        }

        System.debug('headerMap=' + headerMap);

        List<sObject> sObjects = new List<sObject>();
        for (Integer rowNumber = 1; rowNumber < recordsList.size(); rowNumber++) {
            System.debug('recordsList[x]=' + recordsList[rowNumber]);
            sObject sObj = Schema.getGlobalDescribe().get(tableName).newSObject();
            for (Integer fieldNumber = 0; fieldNumber < recordsList[rowNumber].size(); fieldNumber++) {
                String curType = String.valueOf(headerMap.get(recordsList[0][fieldNumber]));
                System.debug('curType=' + curType);
                Object fieldValue = getAdduceValue(curType, recordsList[rowNumber][fieldNumber]);
                sObj.put(recordsList[0][fieldNumber], fieldValue);  


            }
            sObjects.add(sObj);
            System.debug('sObj=' + sObj);
        }
        update(sObjects);

        //List<sObject> sObjects = new List<sObject>();
        //for (Integer rowNumber = 1; rowNumber < records.size(); rowNumber++) {
        //    String row = records[rowNumber].replace('[', ' ').replace(']', ' ');
        //    List<String> fieldNames = new List<String>();
        //    fieldNames = row.split(',');
        //    sObject sObj = Schema.getGlobalDescribe().get(tableName).newSObject();          
        //    for (Integer fieldNumber = 0; fieldNumber < fieldNames.size(); fieldNumber++) {
        //        String curType = String.valueOf(headerMap.get(headerList[fieldNumber].trim()));                
        //        Object fieldValue = fieldNames[fieldNumber].trim();
        //        if (fieldValue != null) {
        //            try {
        //                if (curType == 'DOUBLE') {
        //                    fieldValue = Double.valueOf(fieldNames[fieldNumber].trim());
        //                }
        //                else if (curType == 'DATE') {
        //                    List<String> dateList = fieldNames[fieldNumber].trim().split('/');
        //                    String currentDate = dateList[2] + '-' + dateList[1] + '-' + dateList[0];
        //                    fieldValue = Date.valueOf(currentDate);
        //                }
        //                else if (curType == 'INTEGER') {
        //                    fieldValue = Integer.valueOf(fieldNames[fieldNumber].trim());
        //                }
        //                else if (curType == 'BOOLEAN') {
        //                    fieldValue = Boolean.valueOf(fieldNames[fieldNumber].trim());
        //                }
        //            }
        //            catch(Exception e) {
        //                fieldValue = null;
        //            }
        //        }
        //        sObj.put(headerList[fieldNumber].trim(), fieldValue);
        //    }
        //    sObjects.add(sObj);
        //}
        //update(sObjects);
    }


}