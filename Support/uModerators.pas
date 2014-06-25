unit uModerators;

interface

uses classes, usocialclasses, generics.Collections, usocketcommands, uModerator, uHTTPRequest;

procedure moderators_initialization;
// procedure init;
function BoolToStr(const value: boolean): string;

var
  socVK: tsocialapp;
  tx: integer;
  strings: tstrings;

type
  tmoderators = class
    moderators: TDictionary<int32, Tmoderator>;
    function getModerator(const Index: int32): Tmoderator;
    procedure Access(const ssid: int32);
    procedure updateMessage(ssid: int32; id: int32; type_: boolean); overload;
    procedure updateMessage(ssid: int32; id: int32; message_: string); overload;
    procedure messages(mid: int32; const close: boolean = false);
    procedure messagesArray(const ssid: int32; mid: int32; const APackege: string = 'messages');
    procedure messageAt(ssid, from, to_, state: int32; favorite: int32);
    procedure screenShot(ssid: int32; screen_id: int32);
    procedure messageList(ssid: int32);
    procedure findMessage(ssid, id: int32);
    property moderator[const index: int32]: Tmoderator read getModerator; default;

  end;

  TInit = class
    procedure init;
    procedure test;
  end;

var
  moderators: tmoderators;
  f: textfile;

implementation

uses ulog, utcpserver, uhttpserver, uDBManager, // ugethttpthread,
  {usocketcommands,} {uDefaults,} sysUtils,
  usessions, windows,
  uzipcompressor, ZLIB, messages, // extctrls,
  syncobjs, uunixtime, Math, superobject,
  uconfig, character, OverbyteIcsThreadTimer,
  uLogicThreads, dateutils, ugethttpthread, uScheduler, uMonitor, uinit, uclient;

procedure tmoderators.updateMessage(ssid: int32; id: int32; message_: string);
var
  q: iquery;
begin
  if message_ <> '' then
    try
      queryexec('exec setMessageModerator @id=:id,@moderator_id=:moderator_id,@message=:message,@Time_=:Time_', [id, ssid, message_, now]);
    except
      on E: Exception do
      begin
        log.debug('tmoderators.updateMessage1 Error!' + E.message, true);
        moderators[ssid].writeln('{"response":{"status":0}}');
        Exit;
      end;
    end;
  messages(id);
end;

procedure tmoderators.updateMessage(ssid, id: int32; type_: boolean);
begin
  try
    queryexec('update messageList set favorite=:type_ where id=:id ', [integer(type_), id]);
  except
    on E: Exception do
    begin
      log.debug('tmoderators.updateMessage2 Error!' + E.message, true);
      moderators[ssid].writeln('{"setFavorite":{"status":0}}');
      exit;
    end;
  end;
  moderators[ssid].writeln('{"setFavorite":{"id":' + inttostr(id) + ',"type":' + BoolToStr(type_) + ',"status":1}}');
  messages(id);
end;

procedure tmoderators.messageList(ssid: int32);
var
  ml: ISuperObject;
  mla: ISuperObject;
  messages: ISuperObject;
  screen: ISuperObject;
  S: string;
  i: integer;
  q, ql, qm, qscreen: iquery;
begin
  try
    ml := so;
    ml.O['messageList'] := so;
    q := query('exec getCount', []);
    ml.i['messageList.countScheduled'] := q.geti(0, 'countScheduled');
    ml.i['messageList.countAnswered'] := q.geti(0, 'countAnswered');
    ml.i['messageList.countClosed'] := q.geti(0, 'countClosed');
    ml.i['messageList.countFavorite'] := q.geti(0, 'countFavorite');
    ml.O['messageList.messageList'] := sa([]);
    q := nil;

    ql := query('exec getMessageList @id=:id', [ssid]);
    if ql.recordcount > 0 then
      for i := 0 to ql.recordcount - 1 do
        if moderators[ssid].AccessLGS.CheckAccess(ql.geti(i, 'game_id'), ql.geti(i, 'social_id'), ql.gets(i, 'language')) then
        begin
          mla := so;
          mla.i['id'] := ql.geti(i, 'id');
          mla.S['title'] := ql.gets(i, 'title');
          mla.O['owner'] := so;
          mla.i['owner.socialid'] := ql.geti(i, 'social_id');
          mla.S['owner.viewerid'] := ql.gets(i, 'viewer_id');
          mla.S['owner.firstName'] := ql.gets(i, 'firstName');
          mla.S['owner.lastName'] := ql.gets(i, 'lastName');
          mla.i['owner.userid'] := ql.geti(i, 'userId', -1);
          mla.i['createTime'] := DateTimeToUnix(ql.getd(i, 'createTime'));
          mla.B['favorite'] := ql.getB(i, 'favorite');
          mla.i['lastUpdate'] := DateTimeToUnix(ql.getd(i, 'lastUpdate'));
          mla.S['clientVersion'] := ql.gets(i, 'Version', '');
          mla.S['deviceName'] := ql.gets(i, 'Device', '');
          mla.B['isDonator'] := ql.getB(i, 'isDonator', False);
          mla.S['type'] := ql.gets(i, 'type');
          mla.S['state'] := ql.gets(i, 'state');
          mla.i['game_id'] := ql.geti(i, 'game_id');
          mla.S['language'] := ql.gets(i, 'language');
          ml.A['messageList.messageList'].Add(mla);
        end;
    ml.i['messageList.status'] := 1;
  except
    on E: Exception do
    begin
      ml.i['messageList.status'] := 0;
    end;
  end;
  moderators[ssid].writeln(ml.AsString);
end;

procedure tmoderators.Access(const ssid: int32);
var
  i: int32;
  q: iquery;
  lso: ISuperObject;
  LSOObj: ISuperObject;
begin
  try
    lso := so();
    lso.O['access'] := so();
    lso.O['access'].O['access'] := sa([]);
    q := query('SELECT AG.GameId, AG.UserId, AG.SocialId, AG.[Language], AG.Hide, T1.[Count] FROM AccessGames AS AG LEFT JOIN ' +
      '(SELECT U.social_id,messageList.game_id,messageList.[language], count(messageList.id) as Count ' +
      'FROM users AS u INNER JOIN messageList ON messageList.user_id = u.id WHERE messageList.state_id = 1 ' +
      'GROUP BY U.social_id,messageList.game_id,messageList.[language]) as T1 ' +
      'ON T1.game_id=AG.GameId AND T1.social_id=AG.SocialId AND T1.[language] = AG.[Language] WHERE AG.UserId =:uid', [ssid]);
    for i := 0 to q.recordcount - 1 do
    begin
      LSOObj := so();
      LSOObj.i['gameId'] := q.geti(i, 'GameId');
      LSOObj.i['socialId'] := q.geti(i, 'SocialId');
      LSOObj.S['language'] := q.gets(i, 'Language');
      LSOObj.B['hide'] := q.getB(i, 'Hide', False);
      LSOObj.I['count'] := q.geti(i, 'Count', 0);
      lso.O['access'].A['access'].Add(LSOObj);
    end;
    lso.O['access'].i['status'] := 1;
  except
    on E: Exception do
    begin
      lso.O['access'].i['status'] := 0;
      log.Error('tmoderators.Access: ' + E.message);
    end;
  end;
  moderators[ssid].writeln(lso.AsString);
end;

procedure tmoderators.findMessage(ssid, id: int32);
var
  ml: ISuperObject;
  mla: ISuperObject;
  messages: ISuperObject;
  screen: ISuperObject;
  S: string;
  i, ii: integer;
  q, ql, qm, qscreen: iquery;
  LTitele: string;
begin
  mla := so;
  mla.O['findMessage'] := so;
  try
    ql := query('exec findMessage @id=:id', [id]);
    if ql.recordcount > 0 then
    begin
      mla.i['findMessage.id'] := ql.geti(i, 'id');
      LTitele := StringReplace(ql.gets(i, 'title'), chr(10), ' ', [rfReplaceAll, rfIgnoreCase]);
      LTitele := StringReplace(LTitele, chr(13), ' ', [rfReplaceAll, rfIgnoreCase]);
      mla.S['findMessage.title'] := LTitele;
      mla.O['findMessage.owner'] := so;
      mla.i['findMessage.owner.socialid'] := ql.geti(i, 'social_id');
      mla.S['findMessage.owner.viewerid'] := ql.gets(i, 'viewer_id');
      mla.S['findMessage.owner.firstName'] := ql.gets(i, 'firstName');
      mla.S['findMessage.owner.lastName'] := ql.gets(i, 'lastName');
      mla.i['findMessage.owner.userid'] := ql.geti(i, 'userId', -1);
      mla.i['findMessage.createTime'] := DateTimeToUnix(ql.getd(i, 'createTime'));
      mla.B['findMessage.favorite'] := ql.getB(i, 'favorite');
      mla.i['findMessage.lastUpdate'] := DateTimeToUnix(ql.getd(i, 'lastUpdate'));
      mla.B['findMessage.isDonator'] := ql.getB(i, 'isDonator', False);
      mla.S['findMessage.clientVersion'] := ql.gets(i, 'Version', '');
      mla.S['findMessage.deviceName'] := ql.gets(i, 'Device', '');
      mla.S['findMessage.type'] := ql.gets(i, 'type');
      mla.S['findMessage.state'] := ql.gets(i, 'state');
      mla.i['findMessage.game_id'] := ql.geti(i, 'game_id');
      mla.i['findMessage.status'] := 1;
    end
    else
      mla.i['findMessage.status'] := 0;
  except
    on E: Exception do
    begin
      mla.i['findMessage.status'] := 0;
    end;
  end;
  moderators[ssid].writeln(mla.AsString);
end;

function tmoderators.getModerator(const Index: int32): Tmoderator;
begin
  moderators.TryGetValue(index, Result)
end;

procedure tmoderators.messages(mid: int32; const close: boolean = false);
var
  m: ISuperObject;
  messages: ISuperObject;
  i: integer;
  ql: iquery;
  LModerator: Tmoderator;
  S: string;
begin
  m := so;
  m.O['message'] := so;
  try
    ql := tquery.create('exec getMessage @id=:id', [mid]);
    if ql.recordcount > 0 then
    begin
      m.i['message.id'] := ql.geti(0, 'id');
      m.S['message.title'] := ql.gets(0, 'title');
      m.O['message.owner'] := so;
      m.i['message.owner.socialid'] := ql.geti(0, 'social_id');
      m.S['message.owner.viewerid'] := ql.gets(0, 'viewer_id');
      m.S['message.owner.firstName'] := ql.gets(0, 'firstName');
      m.S['message.owner.lastName'] := ql.gets(0, 'lastName');
      m.i['message.owner.userid'] := ql.geti(0, 'userId', -1);
      m.i['message.createTime'] := DateTimeToUnix(ql.getd(0, 'createTime'));
      m.B['message.favorite'] := ql.getB(0, 'favorite');
      m.i['message.lastUpdate'] := DateTimeToUnix(ql.getd(0, 'lastUpdate'));
      m.B['message.isDonator'] := ql.getB(i, 'isDonator', False);
      m.S['message.clientVersion'] := ql.gets(i, 'Version', '');
      m.S['message.deviceName'] := ql.gets(i, 'Device', '');
      m.S['message.type'] := ql.gets(0, 'type');
      m.S['message.state'] := ql.gets(0, 'state');
      m.i['message.game_id'] := ql.geti(0, 'game_id');
    end;
    m.i['message.status'] := 1;
  except
    on E: Exception do
    begin
      log.Error('tmoderators.messages eroor: message=' + inttostr(mid) + E.message);
      m.i['message.status'] := 0;
    end;
  end;
  for LModerator in moderators.Values do
  begin
    if LModerator.AccessLGS.CheckAccess(ql.geti(0, 'game_id'), ql.geti(0, 'social_id'), ql.gets(0, 'language', '')) or close then
      LModerator.writeln(m.AsString);
  end;
end;

procedure tmoderators.messagesArray(const ssid: int32; mid: int32; const APackege: string = 'messages');
var
  qm: iquery;
  js: ISuperObject;
  json: ISuperObject;
  i: int32;
  LMessage: string;
begin
  js := so;
  js.O[APackege] := so;
  js.O[APackege].O['messages'] := sa([]);

  try
    qm := query('exec getMessages @id=:id', [mid]);
    if qm.recordcount > 0 then
      for i := 0 to qm.recordcount - 1 do
      begin
        json := so;
        json.i['id'] := qm.geti(i, 'id');
        json.S['from'] := qm.gets(i, 'from_');
        json.S['type'] := qm.gets(i, 'type');
        LMessage := StringReplace(qm.gets(i, 'message'), chr(10), ' ', [rfReplaceAll, rfIgnoreCase]);
        LMessage := StringReplace(LMessage, chr(13), ' ', [rfReplaceAll, rfIgnoreCase]);
        json.S['message'] := LMessage;
        // json.i['game_Id'] := qm.geti(i, 'game_id');
        json.i['time'] := DateTimeToUnix(qm.getd(i, 'time'));
        js.O[APackege].A['messages'].Add(json);
      end;
    js.O[APackege].O['screenShots'] := sa([]);
    qm := query('select id from screenShots where messageList_id=:id', [mid]);
    if qm.recordcount > 0 then
      for i := 0 to qm.recordcount - 1 do
      begin
        js.O[APackege].A['screenShots'].i[i] := qm.geti(i, 'id');
      end;
    js.i['messages.status'] := 1;
  except
    on E: Exception do
    begin
      js.i['messages.status'] := 0;
    end;
  end;
  moderators[ssid].writeln(js.AsString);
end;

procedure tmoderators.messageAt(ssid, from, to_, state, favorite: int32);
var
  m: ISuperObject;
  messages: ISuperObject;
  i: integer;
  ql, qm, qsh: iquery;
begin

  m := so;
  m.O['messageAt'] := so;
  m.O['messageAt.messageAt'] := sa([]);
  try
    if (state = 1) or (state = 2) or (state = 3) then
      ql := tquery.create('exec getMessageAtState @w=:back, @q=:next,@state=:state, @Id=:Id', [from, to_, state, ssid])
    else
      ql := tquery.create('exec getMessageAtFavorite @w=:back, @q=:next,@favorite=:favorite, @Id=:id', [from, to_, favorite, ssid]);

    if ql.recordcount > 0 then
      for i := 1 to ql.recordcount - 1 do
      begin
        messages := so;
        messages.i['id'] := ql.geti(i, 'id');
        messages.S['title'] := ql.gets(i, 'title');
        messages.O['owner'] := so;
        messages.i['owner.socialid'] := ql.geti(i, 'social_id');
        messages.S['owner.viewerid'] := ql.gets(i, 'viewer_id');
        messages.S['owner.firstName'] := ql.gets(i, 'firstName');
        messages.S['owner.lastName'] := ql.gets(i, 'lastName');
        messages.i['owner.userid'] := ql.geti(i, 'userId', -1);
        messages.i['createTime'] := DateTimeToUnix(ql.getd(i, 'createTime'));
        messages.B['favorite'] := ql.getB(i, 'favorite');
        messages.i['lastUpdate'] := DateTimeToUnix(ql.getd(i, 'lastUpdate'));
        messages.B['isDonator'] := ql.getB(i, 'isDonator', False);
        messages.S['clientVersion'] := ql.gets(i, 'Version', '');
        messages.S['deviceName'] := ql.gets(i, 'Device', '');
        messages.S['type'] := ql.gets(i, 'type');
        messages.S['state'] := ql.gets(i, 'state');
        messages.i['game_id'] := ql.geti(i, 'game_id');
        m.A['messageAt.messageAt'].Add(messages)
      end;
    qm := nil;
    m.i['messageAt.status'] := 1;
  except
    on E: Exception do
      m.i['messageAt.status'] := 0;
  end;
  moderators[ssid].writeln(m.AsString);
end;

procedure tmoderators.screenShot(ssid: int32; screen_id: int32);
var
  qscreen: iquery;
  screenShot, s1, s2, s3: string;
  js: ISuperObject;
begin
  try
    js := so;
    qscreen := query('exec getImages @id=:id', [screen_id]);
    if qscreen.recordcount > 0 then
    begin
      screenShot := qscreen.gets(0, 'screenShot');
      s1 := Copy(screenShot, length(screenShot) - 3, 4);
      s2 := Copy(screenShot, 1, 4);
      s3 := Copy(screenShot, 1, 3);
      if (length(screenShot) < 2000) or (ansipos(s1, '.jpg.png.bmp.gif.jpeg') <> 0) or (ansipos(s2, 'http') <> 0) or (ansipos(s3, 'www') <> 0) then
        moderators[ssid].writeln('{"screenShots":{"status":1,"screenShot":"' + screenShot + '"}}')
      else
        moderators[ssid].writeln(screenShot, true);
      Finalize(screenShot);
      Finalize(s1);
      Finalize(s2);
      Finalize(s3);
      qscreen := nil;
    end;
  except
    on E: Exception do
      moderators[ssid].writeln('{"screenShots":{"status":0}}');
  end;
end;

procedure TInit.init;
var
  B: boolean;
begin
  try
    moderators_initialization;
    support_initialization;
    tcpserver.Run;
    httpserver.Run;
    log.System('Server started', true);
  except
    on E: Exception do
    begin
      log.Error('Error in Init:' + E.message, true);
    end;
  end;
end;

function BoolToStr(const value: boolean): string;
begin
  if value then
    Result := 'true'
  else
    Result := 'false';
end;

procedure moderators_initialization;
begin
  moderators := tmoderators.create;
  moderators.moderators := TDictionary<int32, Tmoderator>.create;
end;

procedure moderators_finalization;
begin
  freeandnil(moderators);
end;

procedure TInit.test;
var
  LSOTickets, LSOTicket, LSOM: ISuperObject;
  LQML, LQM: iquery;
  i, j: int32;
  LMessage: string;
begin
  // LSOTickets := so();
  // LSOTickets.O['getUserMessages'] := so();
  // LSOTickets.O['getUserMessages'].O['tickets'] := sa([]);
  // LQML := query('exec getMessageListToUser @viewer_id=:viewer_id, @social_id=:social_id,@game_id=:game_id',
  // [7396316, 1, 2]);
  // for i := 0 to LQML.recordcount - 1 do
  // begin
  // LSOTicket := so;
  // LSOTicket.i['id'] := LQML.geti(i, 'id');
  // LSOTicket.S['title'] := LQML.gets(i, 'title');
  // LSOTicket.S['viewer_id'] := LQML.gets(i, 'viewer_id');
  // LSOTicket.i['social_id'] := LQML.geti(i, 'social_id');
  // LSOTicket.S['firstName'] := LQML.gets(i, 'firstName');
  // LSOTicket.S['lastName'] := LQML.gets(i, 'lastName');
  // LSOTicket.i['createTime'] := DateTimeToUnix(LQML.getd(i, 'createTime'));
  // LSOTicket.S['type'] := LQML.gets(i, 'type');
  // LSOTicket.S['state'] := LQML.gets(i, 'state');
  // LSOTicket.i['count'] := LQML.geti(i, 'count');
  // LSOTicket.O['messages'] := sa([]);
  // LSOTicket.O['screenShots'] := sa([]);
  //
  // LQM := query('exec getMessages @id=:id', [LQML.geti(i, 'id')]);
  // for j := 0 to LQM.recordcount - 1 do
  // begin
  // LSOM := so;
  // LSOM := so;
  // LSOM.i['id'] := LQM.geti(j, 'id');
  // LSOM.S['from'] := LQM.gets(j, 'from_');
  // LSOM.S['type'] := LQM.gets(j, 'type');
  // LMessage := StringReplace(LQM.gets(j, 'message'), chr(10), '', [rfReplaceAll, rfIgnoreCase]);
  // LMessage := StringReplace(LMessage, chr(13), '', [rfReplaceAll, rfIgnoreCase]);
  // LSOM.S['message'] := LMessage;
  // LSOM.i['time'] := DateTimeToUnix(LQM.getd(j, 'time'));
  // LSOTicket.A['messages'].Add(LSOM);
  // end;
  // LQM := query('select id from screenShots where messageList_id=:id', [LQML.geti(i, 'id')]);
  // if LQM.recordcount > 0 then
  // for j := 0 to LQM.recordcount - 1 do
  // LSOTicket.A['screenShots'].i[j] := LQM.geti(j, 'id');
  //
  // LSOTickets.o['getUserMessages'].a['tickets'].Add(LSOTicket);
  // end;
  // log.Error(LSOTickets.AsString);
  //
end;

initialization

coreInitialization(TInit.create.init);

finalization

{
  FightDispatcherFinalization;

  units_finalization;
  server_finalization;
  alliances_finalization;
  httpserver.Destroy;

  udbprocessor.DB.Destroy;
}
end.
