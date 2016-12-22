global with sharing class GetRecordsWithJsUCController {

    public String baseURL { get; set; }

    public GetRecordsWithJsUCController() {
        baseURL = URL.getSalesforceBaseUrl().toExternalForm();
    }
    private static final String TABLE_NAME_NONE = '--NONE--';
    
    @RemoteAction
    global static List<String> getTableNames() {
        List<String> tableNames = new List<String>();
        tableNames.add(TABLE_NAME_NONE);
        for (Schema.SObjectType objectType : Schema.getGlobalDescribe().values()) {
            tableNames.add(String.valueOf(objectType));
        }
        tableNames.sort();
        return tableNames;
    }

    @RemoteAction
    global static List<String> getFields(String tableName) {
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
    global static List<Object> runQuery(String tableName, List<String> fields, String sortField, Boolean isASC) {       
        String direction = (isASC) ? 'ASC' : 'DESC';
        String query = 'SELECT ';
        for (String field : fields) {
            query += field + ',';
        }
        query = query.substringBeforeLast(',') + ' FROM ' + tableName + ' ORDER BY ' + sortField + ' ' + direction;

        List<SObject> records = new List<SObject>();
        records = Database.query(query);
        Map<String,Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(tableName).getDescribe().fields.getMap();
        Map<String,Schema.DisplayType> fieldTypeMap = new Map<String,Schema.DisplayType>();
        Map<String, List<String>> piclistValuesMap = new Map<String, List<String>>();

        for (String field : fields) {
            Schema.SObjectField schemaField = fieldMap.get(field.trim());
            Schema.DisplayType fldType = schemaField.getDescribe().getType();
            if (String.valueOf(fldType) == 'PICKLIST' || String.valueOf(fldType) == 'MULTIPICKLIST') {
                List<Schema.PicklistEntry> picklistEntries = fieldMap.get(field).getDescribe().getPickListValues();
                List<String> picklistValues = new List<String>(); 
                for (Schema.PicklistEntry picklistEntry : picklistEntries ) {
                    picklistValues.add(picklistEntry.getValue());
                }
                piclistValuesMap.put(field, picklistValues);
            }
            fieldTypeMap.put(field, fldType);
        }

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
        Object resultValue = (value == '') ? null : value;

        if (resultValue != null) {
            try {
                if (fieldType == 'DOUBLE') {
                    resultValue = Double.valueOf(value);
                }
                if (fieldType == 'DECIMAL') {
                    resultValue = Decimal.valueOf(value);
                }
                else if (fieldType == 'DATE') {
                    resultValue = Date.valueOf(value);
                }
                else if (fieldType == 'DATETIME') {
                    resultValue = Date.valueOf(value);
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
                System.debug('Exception=' + e.getMessage());
            }
        }
        return resultValue;
    }

    @RemoteAction
    global static void saveListObjects(String rec, String tableName) {
        List<List<String>> recordsList = (List<List<String>>)System.JSON.deserialize(rec, List<List<String>>.class);
       
        Map<String,Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(tableName).getDescribe().fields.getMap();
        Map<String,Schema.DisplayType> headerMap = new Map<String,Schema.DisplayType>(); 
        for (String header : recordsList[0]) {
            Schema.SObjectField field = fieldMap.get(header.trim());
            Schema.DisplayType fldType = field.getDescribe().getType();
            headerMap.put(header.trim(), fldType);
        }

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
        }
        update(sObjects);        
    }

}