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
            tableNames.add(String.valueOf(objectType).toUpperCase());
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
    public static List<Object> runQuery(String tableName, List<String> fields) {
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

}