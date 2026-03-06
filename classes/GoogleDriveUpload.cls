public with sharing class GoogleDriveUpload {

    @AuraEnabled
    public static String uploadToFolder(
        String fileName,
        String base64Data,
        String folderId
    ) {
        String boundary = '-------314159265358979323846';

        String metadata =
            '{"name":"' + fileName + '",' +
            '"parents":["' + folderId + '"]}';

        String body =
            '--' + boundary + '\n' +
            'Content-Type: application/json; charset=UTF-8\n\n' +
            metadata + '\n' +
            '--' + boundary + '\n' +
            'Content-Type: application/octet-stream\n' +
            'Content-Transfer-Encoding: base64\n\n' +
            base64Data + '\n' +
            '--' + boundary + '--';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GoogleDrive/upload/drive/v3/files?uploadType=multipart');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/related; boundary=' + boundary);
        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        return res.getBody();
    }

    @AuraEnabled
    public static String checkOrCreateSubFolder(
        String parentFolderId,
        String accountId,
        Boolean createIfMissing
    ) {
        String query =
            '\'' + parentFolderId + '\' in parents' +
            ' and mimeType = \'application/vnd.google-apps.folder\'' +
            ' and name = \'' + accountId + '\'' +
            ' and trashed = false';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'callout:GoogleDrive/drive/v3/files?q=' +
            EncodingUtil.urlEncode(query, 'UTF-8')
        );
        req.setMethod('GET');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Folder search failed');
        }

        Map<String, Object> result =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        List<Object> files =
            (List<Object>) result.get('files');

        if (!files.isEmpty()) {
            Map<String, Object> folder =
                (Map<String, Object>) files[0];

            String existingFolderId =
                (String) folder.get('id');

            makeFolderPublic(existingFolderId);

            return existingFolderId;
        }

        if (!createIfMissing) {
            return null;
        }

        Map<String, Object> metadata = new Map<String, Object>{
            'name'     => accountId,
            'mimeType' => 'application/vnd.google-apps.folder',
            'parents'  => new List<String>{ parentFolderId }
        };

        HttpRequest createReq = new HttpRequest();
        createReq.setEndpoint('callout:GoogleDrive/drive/v3/files');
        createReq.setMethod('POST');
        createReq.setHeader('Content-Type', 'application/json');
        createReq.setBody(JSON.serialize(metadata));

        HttpResponse createRes = http.send(createReq);

        if (createRes.getStatusCode() == 200 ||
            createRes.getStatusCode() == 201) {

            Map<String, Object> createResult =
                (Map<String, Object>) JSON.deserializeUntyped(createRes.getBody());

            String newFolderId =
                (String) createResult.get('id');

            makeFolderPublic(newFolderId);

            return newFolderId;
        }

        throw new AuraHandledException('Folder creation failed');
    }

    private static void makeFolderPublic(String folderId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GoogleDrive/drive/v3/files/' + folderId + '/permissions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"role":"reader","type":"anyone"}');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200 &&
            res.getStatusCode() != 201 &&
            res.getStatusCode() != 409) {

            throw new AuraHandledException('Failed to make folder public');
        }
    }

    @AuraEnabled
    public static String getFilesFromFolder(String folderId) {
        String query =
            '\'' + folderId + '\' in parents and trashed = false';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'callout:GoogleDrive/drive/v3/files?q=' +
            EncodingUtil.urlEncode(query, 'UTF-8') +
            '&fields=files(id,name,mimeType,webViewLink,size)'
        );
        req.setMethod('GET');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to fetch files');
        }

        return res.getBody();
    }

    @AuraEnabled
    public static void deleteFile(String fileId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GoogleDrive/drive/v3/files/' + fileId);
        req.setMethod('DELETE');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 204) {
            throw new AuraHandledException('Failed to delete file');
        }
    }

    @AuraEnabled
    public static String checkExistingReport(String folderId, Id accountId) {
        String expectedFileName =
            'Account_Report_' + accountId + '.pdf';

        String query =
            '\'' + folderId + '\' in parents' +
            ' and name = \'' + expectedFileName + '\'' +
            ' and trashed = false';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'callout:GoogleDrive/drive/v3/files?q=' +
            EncodingUtil.urlEncode(query, 'UTF-8') +
            '&fields=files(id,name)'
        );
        req.setMethod('GET');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to check existing report');
        }

        Map<String, Object> result =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        List<Object> files =
            (List<Object>) result.get('files');

        if (!files.isEmpty()) {
            Map<String, Object> file =
                (Map<String, Object>) files[0];

            return (String) file.get('id');
        }

        return null;
    }

    @AuraEnabled
    public static void generateAndUploadAccountReport(
        Id accountId,
        String folderId
    ) {
        Blob pdfBlob =
            AccountPdfGenerator.generateAccountPdf(accountId);

        String base64Data =
            EncodingUtil.base64Encode(pdfBlob);

        String fileName =
            'Account_Report_' + accountId + '.pdf';

        uploadToFolder(fileName, base64Data, folderId);
    }
}