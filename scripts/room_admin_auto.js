function sendMail(in_out) {
  const name = "塚本";

  const query = "subject:入退室報告", start = 0, max = 1;
  var firstThread = GmailApp.search(query, start, max)[0];
  const now = new Date();

  if (in_out == 0) {
    var in_out_text = "入室しました．"
  } else {
    var in_out_text = "退室しました．"
  }

  var text = name + "です．\n\n" + in_out_text + "\n\n日時：" + date2String(now) + "\n場所：73B2";
  
  // Logger.log(text); // デバッグ
  firstThread.replyAll(text);
}

function date2String(str) {
  return Utilities.formatDate(str, 'JST', 'yyyy/MM/dd HH:mm');
}

function doGet(e) {
  sendMail(e.parameter.in_out);
}
