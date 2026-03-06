public with sharing class AccountPdfGenerator {

    @AuraEnabled
    public static Blob generateAccountPdf(Id accountId) {

        Account acc = [
            SELECT Name, Type, Industry, Rating,
                   Phone, Website,
                   AnnualRevenue, NumberOfEmployees,
                   BillingCity, BillingState, BillingCountry,
                   Description,
                   (SELECT Name, Email, Phone FROM Contacts LIMIT 5),
                   (SELECT Name, StageName, Amount, CloseDate FROM Opportunities LIMIT 5)
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        String html = '';

        html += '<html>';
        html += '<body style="margin:6px;font-family:Arial,Helvetica,sans-serif;background:#F4F6F9;">';

        // ================= HEADER =================
        html += '<table width="100%" style="border-collapse:collapse;">';
        html += '<tr>';
        html += '<td style="background:#0176D3;color:white;padding:16px;font-size:20px;font-weight:bold;">';
        html += 'ACCOUNT REPORT';
        html += '</td>';
        html += '</tr>';
        html += '<tr>';
        html += '<td style="padding:6px 0;font-size:11px;color:#444;">';
        html += 'Generated on ' + DateTime.now().format();
        html += '</td>';
        html += '</tr>';
        html += '</table>';

        // ================= ACCOUNT DETAILS =================
        html += sectionTitle('Account Details');

        html += '<table width="100%" style="border-collapse:collapse;font-size:12px;background:white;">';

        html += buildRow('Account Name', acc.Name, 'Type', acc.Type, true);
        html += buildRow('Industry', acc.Industry, 'Rating', acc.Rating, false);
        html += buildRow('Phone', acc.Phone, 'Website', acc.Website, true);
        html += buildRow('Annual Revenue',
                         acc.AnnualRevenue != null ? String.valueOf(acc.AnnualRevenue) : '-',
                         'Employees',
                         acc.NumberOfEmployees != null ? String.valueOf(acc.NumberOfEmployees) : '-', false);
        html += buildRow('City', acc.BillingCity, 'State', acc.BillingState, true);
        html += buildRow('Country', acc.BillingCountry, 'Description', acc.Description, false);

        html += '</table>';

        // ================= CONTACT SECTION =================
        html += sectionTitle('Related Contacts');

        html += '<table width="100%" style="border-collapse:collapse;font-size:12px;background:white;">';
        html += tableHeader('Name', 'Email', 'Phone');

        if (!acc.Contacts.isEmpty()) {
            for (Contact con : acc.Contacts) {
                html += contactRow(con.Name, con.Email, con.Phone);
            }
        } else {
            html += emptyRow('No related contacts found');
        }

        html += '</table>';

        // ================= OPPORTUNITY SECTION =================
        html += sectionTitle('Related Opportunities');

        html += '<table width="100%" style="border-collapse:collapse;font-size:12px;background:white;">';
        html += tableHeader('Name', 'Stage', 'Amount', 'Close Date');

        if (!acc.Opportunities.isEmpty()) {
            for (Opportunity opp : acc.Opportunities) {
                html += opportunityRow(
                    opp.Name,
                    opp.StageName,
                    opp.Amount != null ? String.valueOf(opp.Amount) : '-',
                    opp.CloseDate != null ? String.valueOf(opp.CloseDate) : '-'
                );
            }
        } else {
            html += emptyRow('No related opportunities found');
        }

        html += '</table>';

        html += '</body>';
        html += '</html>';

        return Blob.toPdf(html);
    }

    // ================= HELPER METHODS =================

    private static String sectionTitle(String title) {
        return
        '<div style="margin-top:20px;margin-bottom:6px;font-weight:bold;font-size:14px;color:#032D60;">'
        + safe(title) +
        '</div>';
    }

    private static String tableHeader(String col1, String col2, String col3) {
        return
        '<tr style="background:#E3F2FD;font-weight:bold;">' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + col1 + '</td>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + col2 + '</td>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + col3 + '</td>' +
        '</tr>';
    }

    private static String tableHeader(String col1, String col2, String col3, String col4) {
        return
        '<tr style="background:#E3F2FD;font-weight:bold;">' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + col1 + '</td>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + col2 + '</td>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + col3 + '</td>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + col4 + '</td>' +
        '</tr>';
    }

    private static String contactRow(String name, String email, String phone) {
        return
        '<tr>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + safe(name) + '</td>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + safe(email) + '</td>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + safe(phone) + '</td>' +
        '</tr>';
    }

    private static String opportunityRow(String name, String stage, String amount, String closeDate) {
        return
        '<tr>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + safe(name) + '</td>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + safe(stage) + '</td>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + safe(amount) + '</td>' +
        '<td style="padding:6px;border:1px solid #D8DDE6;">' + safe(closeDate) + '</td>' +
        '</tr>';
    }

    private static String emptyRow(String message) {
        return
        '<tr>' +
        '<td colspan="4" style="padding:6px;border:1px solid #D8DDE6;text-align:center;color:#888;">'
        + message +
        '</td>' +
        '</tr>';
    }

    private static String buildRow(String label1, String value1,
                                   String label2, String value2,
                                   Boolean shaded) {

        String bgColor = shaded ? '#F0F8FF' : '#FFFFFF';

        return
        '<tr style="background:' + bgColor + ';">' +
        '<td style="padding:8px;border:1px solid #D8DDE6;font-weight:bold;width:20%;">'
        + safe(label1) + '</td>' +
        '<td style="padding:8px;border:1px solid #D8DDE6;width:30%;">'
        + safe(value1) + '</td>' +
        '<td style="padding:8px;border:1px solid #D8DDE6;font-weight:bold;width:20%;">'
        + safe(label2) + '</td>' +
        '<td style="padding:8px;border:1px solid #D8DDE6;width:30%;">'
        + safe(value2) + '</td>' +
        '</tr>';
    }

    private static String safe(String value) {
        return value == null ? '-' : value.escapeHtml4();
    }
}