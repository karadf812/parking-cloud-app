
public with sharing class ParkingController {

    public class SensorPagedResult {
        @AuraEnabled public List<Sensor__c> sensors { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static Integer getDefaultPageSize() {
        Parking_Settings__c settings = Parking_Settings__c.getInstance();

        if (settings != null && settings.Default_Page_Size__c != null) {
            return Integer.valueOf(settings.Default_Page_Size__c);
        }

        return 10;
    }

    @AuraEnabled(cacheable=true)
    public static SensorPagedResult getSensors(
        String statusFilter,
        Integer pageNumber,
        Integer pageSize
    ) {
        if (pageNumber == null || pageNumber < 1) {
            pageNumber = 1;
        }

        if (pageSize == null || pageSize < 1) {
            pageSize = getDefaultPageSize();
        }

        // Prevent excessively large page requests.
        pageSize = Math.min(pageSize, 200);

        String queryBase = ' FROM Sensor__c';
        String whereClause = '';

        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            whereClause = ' WHERE Status__c = :statusFilter';
        }

        Integer totalRecords = Database.countQuery(
            'SELECT COUNT()' + queryBase + whereClause
        );

        Integer offsetValue = (pageNumber - 1) * pageSize;

        String dataQuery =
            'SELECT Id, Name, Sensor_Model__c, Status__c, ' +
            'Base_Station__c, Base_Station__r.Name ' +
            queryBase + whereClause +
            ' ORDER BY CreatedDate DESC LIMIT :pageSize OFFSET :offsetValue';

        SensorPagedResult result = new SensorPagedResult();
        result.sensors = Database.query(dataQuery);
        result.totalRecords = totalRecords;
        result.pageSize = pageSize;
        result.pageNumber = pageNumber;

        return result;
    }

    @AuraEnabled
    public static void processCsvUpload(String base64Data) {
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException(
                'CSV file content cannot be blank.'
            );
        }

        String fileContent;

        try {
            fileContent = EncodingUtil.base64Decode(base64Data).toString();
        } catch (Exception e) {
            throw new AuraHandledException(
                'The uploaded file could not be decoded.'
            );
        }

        List<String> lines = fileContent.split('\n');

        if (lines.size() <= 1) {
            throw new AuraHandledException(
                'CSV file is empty or contains only headers.'
            );
        }

        Map<String, Base_Station__c> stationMap =
            new Map<String, Base_Station__c>();

        for (Base_Station__c station : [
            SELECT Id, Name
            FROM Base_Station__c
        ]) {
            if (String.isNotBlank(station.Name)) {
                stationMap.put(
                    station.Name.trim().toLowerCase(),
                    station
                );
            }
        }

        List<Base_Station__c> stationsToInsert =
            new List<Base_Station__c>();

        List<String> newStationKeys = new List<String>();
        List<Sensor__c> sensorsToInsert = new List<Sensor__c>();

        for (Integer i = 1; i < lines.size(); i++) {
            String line = lines[i].trim();

            if (String.isBlank(line)) {
                continue;
            }

            // Basic CSV parsing. Quoted commas require a proper CSV parser.
            List<String> csvRow = line.split(',');

            if (csvRow.size() < 3) {
                continue;
            }

            String sensorModel = csvRow[0].trim();
            String sensorStatus = csvRow[1].trim();
            String stationName = csvRow[2].trim();

            if (
                String.isBlank(sensorModel) ||
                String.isBlank(sensorStatus) ||
                String.isBlank(stationName)
            ) {
                continue;
            }

            String stationKey = stationName.toLowerCase();

            if (!stationMap.containsKey(stationKey)) {
                Base_Station__c newStation = new Base_Station__c(
                    Name = stationName,
                    Status__c = 'Active'
                );

                stationsToInsert.add(newStation);
                newStationKeys.add(stationKey);

                // Prevent duplicate stations in the same CSV.
                stationMap.put(stationKey, newStation);
            }

            Base_Station__c targetStation = stationMap.get(stationKey);

            sensorsToInsert.add(
                new Sensor__c(
                    Sensor_Model__c = sensorModel,
                    Status__c = sensorStatus,
                    Base_Station__c = targetStation.Id
                )
            );
        }

        if (!stationsToInsert.isEmpty()) {
            insert stationsToInsert;

            for (Integer i = 0; i < stationsToInsert.size(); i++) {
                stationMap.put(
                    newStationKeys[i],
                    stationsToInsert[i]
                );
            }

            // Assign inserted station IDs to sensors that reference new stations.
            Integer sensorIndex = 0;

            for (Integer i = 1; i < lines.size(); i++) {
                String line = lines[i].trim();

                if (String.isBlank(line)) {
                    continue;
                }

                List<String> csvRow = line.split(',');

                if (
                    csvRow.size() < 3 ||
                    String.isBlank(csvRow[0].trim()) ||
                    String.isBlank(csvRow[1].trim()) ||
                    String.isBlank(csvRow[2].trim())
                ) {
                    continue;
                }

                String stationKey = csvRow[2].trim().toLowerCase();

                if (stationMap.containsKey(stationKey)) {
                    sensorsToInsert[sensorIndex].Base_Station__c =
                        stationMap.get(stationKey).Id;
                }

                sensorIndex++;
            }
        }

        if (!sensorsToInsert.isEmpty()) {
            insert sensorsToInsert;
        }
    }

    @AuraEnabled
    public static void deleteSensor(String recordId) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException(
                'Sensor record ID is required.'
            );
        }

        try {
            Id sensorId = Id.valueOf(recordId);

            if (sensorId.getSObjectType() != Sensor__c.SObjectType) {
                throw new AuraHandledException(
                    'The supplied ID is not a Sensor record.'
                );
            }

            List<Sensor__c> sensors = [
                SELECT Id
                FROM Sensor__c
                WHERE Id = :sensorId
                LIMIT 1
            ];

            if (!sensors.isEmpty()) {
                delete sensors;
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to delete the sensor. Check the record ID and permissions.'
            );
        }
    }
}
