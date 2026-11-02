import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_inbox.dart';
void main(){testWidgets('inbox separates work from support and sends persisted support messages',(tester) async {
 final stored=<Map<String,dynamic>>[];
 final session=Session(api:Api(base:'http://localhost/api/v1',client:MockClient((r) async {
   if(r.method=='POST'){final data=jsonDecode(r.body);stored.add({'id':data['requestId'],'sender':'USER','content':data['text']});}
   return http.Response(jsonEncode({'success':true,'data':r.url.path.endsWith('/support/messages')?stored:[]}),200,headers:{'content-type':'application/json'});
 })));session.access='access';session.expires=DateTime.now().add(const Duration(hours:1));
 await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:PartnerInbox(session:session)))));await tester.pumpAndSettle();
 expect(find.text('Nhắn tin & tiến trình công việc'),findsOneWidget);
 await tester.tap(find.text('Hỗ trợ'));await tester.pumpAndSettle();
 expect(find.text('Trợ lý AI'),findsOneWidget);await tester.tap(find.text('Chăm sóc khách hàng'));await tester.pumpAndSettle();
 await tester.enterText(find.byType(TextField),'Tôi cần hỗ trợ');await tester.tap(find.byIcon(Icons.send));await tester.pumpAndSettle();
 expect(stored.single['content'],'Tôi cần hỗ trợ');expect(find.text('Tôi cần hỗ trợ'),findsOneWidget);
 await tester.pumpWidget(const SizedBox());session.dispose();
});}
