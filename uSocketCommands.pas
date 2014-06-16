unit usocketcommands;

interface

uses psAPI, Winapi.Windows, uioclasses, uSocialClasses, generics.Collections,
  vcl.imaging.JPEG, vcl.imaging.PNGImage,
  vcl.Graphics, vcl.Controls, vcl.Forms, vcl.ExtCtrls, uLogicThreads;
procedure Support_initialization;
procedure Support_finalization;

const
  secretkey = '87hdfsaGGsdnvzoKQ82BzgweWQ';

type
  TSupport = class

    procedure Support_auth(io: tioclass);
{$IFDEF DEBUG}
    procedure Supportauth(io: tioclass);
{$ENDIF}
    // Moderator
    procedure GetMessages(io: tioclass);
    procedure GetScreenShot(io: tioclass);
    procedure GetMessageAt(io: tioclass);
    procedure Response(io: tioclass);
    procedure SetFavorite(io: tioclass);
    procedure SetClose(io: tioclass);
    procedure DeleteMessage(io: tioclass);
    procedure FindMessage(io: tioclass);
    procedure UpdateAccess(io: tioclass);
    procedure GetUserMessages(io: tioclass);
    procedure GetUserMessagesFromUserId(io: tioclass);

    procedure GetModerators(io: tioclass);
    procedure GetModeratorResponseTikets(io: tioclass);
    procedure GetModeratorMessages(io: tioclass);

    // User
    // procedure getImage(io: tioclass);
    procedure SetImage(io: tioclass);
    procedure SetScreenShot(io: tioclass);
    procedure GetID(io: tioclass);
    procedure DelImage(io: tioclass);
    procedure GetMessageList(io: tioclass);
    procedure GetChainofMessages(io: tioclass);
    procedure SetMessageList(io: tioclass);
    procedure SetMessage(io: tioclass);
    procedure ReadTicket(io: tioclass);
    procedure UnReadTiketCount(io: tioclass);
    procedure EstimateTiket(io: tioclass);

  end;

  Tscreenpool = class
    id: int32;
    screenshot: string;
    func: string;
    time: tdatetime;
    screenNotification: thandle;
    procedure screenDeletePool;
  end;

var
  support: TSupport;
  screen: Tscreenpool;
  screenShotPool: TDictionary<int32, Tscreenpool>;
  max_id_screen: int32;
function checkuser(server_key: string; viewer_id: string): boolean;
function ResizeBmp(bitmp: TBitmap; wid, hei: Integer): boolean;

implementation

uses ucommandprocessor, superobject, uclient, sysutils, ulog,
  uDBManager, umd5hash, {unpcs, ulocationcells, umovement,} syncobjs,
  uModerator, uModerators,
  uscheduler, Classes, usessions,
  math, uthreads,
  uconstants, dateutils, uExceptions, ustrings;

procedure Tscreenpool.screenDeletePool;
var
  temp: Tscreenpool;
  i: int32;
begin
  if screenShotPool.Count > 0 then
    for temp in screenShotPool.Values do
    begin
      if minuteof(now - temp.time) >= 7 then
      begin
        i := temp.id;
        screen := screenShotPool.Items[i];
        screenShotPool.Remove(i);
        Finalize(screen.screenshot);
        FreeAndNil(screen);
      end;
    end;
end;

function checkuser(server_key: string; viewer_id: string): boolean;

var
  s: string;

begin
  try
    if (server_key = lowercase(md5hash(viewer_id + '_' + secretkey))) then
      result := true
    else
    begin
      result := false;
    end;
  except
    on E: Exception do
    begin
      raise Exception.create('Error in checkuser :' + viewer_id + '_' + server_key + '   err:' + E.message);
    end;
  end;
end;

function ResizeBmp(bitmp: TBitmap; wid, hei: Integer): boolean;
var
  TmpBmp: TBitmap;
  ARect: TRect;
begin
  result := false;
  try
    TmpBmp := TBitmap.create;
    try
      TmpBmp.Transparent := true;
      TmpBmp.Width := wid;
      TmpBmp.Height := hei;
      ARect := Rect(0, 0, wid, hei);
      // TmpBmp.Canvas.st
      TmpBmp.Canvas.StretchDraw(ARect, bitmp);
      bitmp.Assign(TmpBmp);
    finally
      TmpBmp.Free;
    end;
    result := true;
  except
    result := false;
  end;
end;

procedure TSupport.Support_auth(io: tioclass);
var
  login, password: string;
  id, access: int32;
  q, q1: IQuery;
  session: Tsession;
  LAccessGames: int32;
  i: int32;
begin
  login := io.iSO.s['login'];
  password := io.iSO.s['password'];

  q := Query('select top 1 * from moderators where login=:login', [login]);
  if q.recordcount > 0 then
  begin
    if password = q.getS(0, 'password') then
    begin
      id := q.geti(0, 'id');
      access := q.geti(0, 'access');
      q := nil;

      sessions.AssignClientToSession(sessions.gensession(id), io.client);

      try
        session := sessions[id].lockandget;
        if session.account = nil then
        begin
          session.account := TModerator.create;
          TModerator(session.account).id := id;
          TModerator(session.account).access := access;
          TModerator(session.account).client := io.client;
          TModerator(session.account).client.ssid := id;
          moderators.moderators.add(id, session.account);
        end
        else
        begin
          TModerator(session.account).client := io.client;
          TModerator(session.account).client.ssid := id;
          TModerator(session.account).client.connected := true;
        end;
        if TModerator(session.account).AccessLGS <> nil then
          TModerator(session.account).AccessLGS.Destroy;
        TModerator(session.account).AccessLGS := TAccessList.create(id);
      finally
        sessions[id].Unlock;
      end;
      moderators.access(id);
      moderators.messageList(id);
    end;
  end
  else
    io.client.write('{"userAuth":{"status":0}}');
end;
{$IFDEF DEBUG}


procedure TSupport.Supportauth(io: tioclass);
var
  login, password: string;
  id, access: int32;
  q, q1: IQuery;
  session: Tsession;
  LAccessGames: int32;
  i: Integer;
begin
  login := io.iSO.s['login'];
  password := io.iSO.s['password'];

  q := Query('select top 1 * from moderators where login=:login', [login]);
  if q.recordcount > 0 then
  begin
    if password = q.getS(0, 'password') then
    begin
      id := q.geti(0, 'id');
      access := q.geti(0, 'access');
      q := nil;

      sessions.AssignClientToSession(sessions.gensession(id), io.client);

      try
        session := sessions[id].lockandget;
        if session.account = nil then
        begin
          session.account := TModerator.create;
          TModerator(session.account).id := id;
          TModerator(session.account).access := access;
          TModerator(session.account).client := io.client;
          TModerator(session.account).client.ssid := id;
          moderators.moderators.add(id, session.account);
        end
        else
        begin
          TModerator(session.account).client := io.client;
          TModerator(session.account).client.ssid := id;
          TModerator(session.account).client.connected := true;
        end;
        if TModerator(session.account).AccessLGS <> nil then
          TModerator(session.account).AccessLGS.Destroy;
        TModerator(session.account).AccessLGS := TAccessList.create(id);
      finally
        sessions[id].Unlock;
      end;
      moderators.access(id);
      moderators.messageList(id);
    end;
  end
  else
    io.client.write('{"userAuth":{"status":0}}');
end;
{$ENDIF}


procedure TSupport.UnReadTiketCount(io: tioclass);
var
  auth_key, viewer_id, server_key, func: string;
  q: IQuery;
begin
  auth_key := io.iSO.s['auth_key'];
  viewer_id := io.iSO.s['viewer_id'];
  server_key := io.iSO.s['server_key'];
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
  io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
  io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
  io.client.writeheaderhttp('Content-Type: text/html; charset=UTF-8');
  io.client.writeheaderhttp('Content-Type, X-Requested-With, X-File-Size, X-File-Name');
  io.client.writeheaderhttp('Content-Type:application/json; charset=UTF-8');
  func := io.iSO.s['jsonp_messageList'];
  if not(checkuser(server_key, viewer_id)) then
  begin
    io.client.writelnHTTPNH('Попробуйте зайти в игру из другого браузера или опишите проблему в группе.');
    exit;
  end;
  try
    q := Query
      ('select count(messageList.id) as count from messageList, users where messagelist.user_id=users.id AND messageList.game_id=:game_id AND users.viewer_id=:viewer_id AND '
      +
      'users.social_id=:social_id and state_id=2', [io.iSO.i['game_id'], io.iSO.s['viewer_id'], io.iSO.i['social_id']]);
  except
    on E: Exception do
    begin
      io.client.writelnHTTPNH('{"unReadTiketCount":{"status":0}}');
      exit;
    end;
  end;
  io.client.writelnHTTPNH('{"unReadTiketCount":{"status":1,"count":' + inttostr(q.geti(0, 'count', 0)) + '}}');
  q := nil;
end;

procedure TSupport.UpdateAccess(io: tioclass);
var
  LQueryString: string;
  i: int32;
begin
  for i := 0 to io.iSO.a['access'].Length - 1 do
    LQueryString := LQueryString + ' exec UpdateAccess ' +
      '@UserId = ' + inttostr(io.ssid) + ', ' +
      '@GameId = ' + inttostr(io.iSO.a['access'][i].i['gameId']) + ', ' +
      '@SocialId = ' + inttostr(io.iSO.a['access'][i].i['socialId']) + ', ' +
      '@Language = ''' + io.iSO.a['access'][i].s['language'] + ''', ' +
      '@Hide = ' + inttostr(io.iSO.a['access'][i].i['hide']) + ' ';
  QueryExec(LQueryString, []);

  if moderators[io.ssid].AccessLGS <> nil then
    moderators[io.ssid].AccessLGS.Destroy;
  moderators[io.ssid].AccessLGS := TAccessList.create(io.ssid);

  moderators.messageList(io.ssid);
end;

procedure TSupport.GetMessages(io: tioclass);
var
  id: int32;
begin
  id := io.iSO.i['id'];
  moderators.messagesArray(io.ssid, id);
end;

procedure TSupport.GetScreenShot(io: tioclass);
var
  screen_id: int32;
begin
  screen_id := io.iSO.i['id'];
  moderators.screenshot(io.ssid, screen_id);
end;

procedure TSupport.GetUserMessages(io: tioclass);
var
  LSOTickets, LSOTicket, LSOM: ISuperObject;
  LQML, LQM: IQuery;
  i, j: int32;
  Lmessage: string;
begin
  LSOTickets := SO();
  LSOTickets.O['getUserMessages'] := SO();
  LSOTickets.O['getUserMessages'].O['tickets'] := SA([]);
  LQML := Query('exec getMessageListToUser @viewer_id=:viewer_id, @social_id=:social_id,@game_id=:game_id',
    [io.iSO.s['viewerId'], io.iSO.i['socialId'], io.iSO.i['gameId']]);
  for i := 0 to LQML.recordcount - 1 do
  begin
    LSOTicket := SO;
    LSOTicket.i['id'] := LQML.geti(i, 'id');
    LSOTicket.s['title'] := LQML.getS(i, 'title');
    LSOTicket.s['viewer_id'] := LQML.getS(i, 'viewer_id');
    LSOTicket.i['social_id'] := LQML.geti(i, 'social_id');
    LSOTicket.s['firstName'] := LQML.getS(i, 'firstName');
    LSOTicket.s['lastName'] := LQML.getS(i, 'lastName');
    LSOTicket.i['createTime'] := DateTimeToUnix(LQML.getd(i, 'createTime'));
    LSOTicket.s['type'] := LQML.getS(i, 'type');
    LSOTicket.s['state'] := LQML.getS(i, 'state');
    LSOTicket.i['count'] := LQML.geti(i, 'count');
    LSOTicket.O['messages'] := SA([]);
    LSOTicket.O['screenShots'] := SA([]);

    LQM := Query('exec getMessages @id=:id', [LQML.geti(i, 'id')]);
    for j := 0 to LQM.recordcount - 1 do
    begin
      LSOM := SO;
      LSOM := SO;
      LSOM.i['id'] := LQM.geti(j, 'id');
      LSOM.s['from'] := LQM.getS(j, 'from_');
      LSOM.s['type'] := LQM.getS(j, 'type');
      Lmessage := StringReplace(LQM.getS(j, 'message'), chr(10), '', [rfReplaceAll, rfIgnoreCase]);
      Lmessage := StringReplace(Lmessage, chr(13), '', [rfReplaceAll, rfIgnoreCase]);
      LSOM.s['message'] := Lmessage;
      LSOM.i['time'] := DateTimeToUnix(LQM.getd(j, 'time'));
      LSOTicket.a['messages'].add(LSOM);
    end;
    LQM := Query('select id from screenShots where messageList_id=:id', [LQML.geti(i, 'id')]);
    if LQM.recordcount > 0 then
      for j := 0 to LQM.recordcount - 1 do
        LSOTicket.a['screenShots'].i[j] := LQM.geti(j, 'id');

    LSOTickets.O['getUserMessages'].a['tickets'].add(LSOTicket);
  end;
  moderators[io.ssid].writeln(LSOTickets.AsString);
end;

procedure TSupport.GetUserMessagesFromUserId(io: tioclass);
var
  LSOTickets, LSOTicket, LSOM: ISuperObject;
  LQML, LQM: IQuery;
  i, j: int32;
  Lmessage: string;
begin
  LSOTickets := SO();
  LSOTickets.O['getUserMessages'] := SO();
  LSOTickets.O['getUserMessages'].O['tickets'] := SA([]);
  LQML := Query('exec GetUserMessagesFromUserId @UserId=:UserId',
    [io.iSO.s['userId']]);
  for i := 0 to LQML.recordcount - 1 do
  begin
    LSOTicket := SO;
    LSOTicket.i['id'] := LQML.geti(i, 'id');
    LSOTicket.s['title'] := LQML.getS(i, 'title');
    LSOTicket.s['viewer_id'] := LQML.getS(i, 'viewer_id');
    LSOTicket.i['social_id'] := LQML.geti(i, 'social_id');
    LSOTicket.s['firstName'] := LQML.getS(i, 'firstName');
    LSOTicket.s['lastName'] := LQML.getS(i, 'lastName');
    LSOTicket.i['createTime'] := DateTimeToUnix(LQML.getd(i, 'createTime'));
    LSOTicket.s['type'] := LQML.getS(i, 'type');
    LSOTicket.s['state'] := LQML.getS(i, 'state');
    LSOTicket.i['count'] := LQML.geti(i, 'count');
    LSOTicket.O['messages'] := SA([]);
    LSOTicket.O['screenShots'] := SA([]);

    LQM := Query('exec getMessages @id=:id', [LQML.geti(i, 'id')]);
    for j := 0 to LQM.recordcount - 1 do
    begin
      LSOM := SO;
      LSOM := SO;
      LSOM.i['id'] := LQM.geti(j, 'id');
      LSOM.s['from'] := LQM.getS(j, 'from_');
      LSOM.s['type'] := LQM.getS(j, 'type');
      Lmessage := StringReplace(LQM.getS(j, 'message'), chr(10), '', [rfReplaceAll, rfIgnoreCase]);
      Lmessage := StringReplace(Lmessage, chr(13), '', [rfReplaceAll, rfIgnoreCase]);
      LSOM.s['message'] := Lmessage;
      LSOM.i['time'] := DateTimeToUnix(LQM.getd(j, 'time'));
      LSOTicket.a['messages'].add(LSOM);
    end;
    LQM := Query('select id from screenShots where messageList_id=:id', [LQML.geti(i, 'id')]);
    if LQM.recordcount > 0 then
      for j := 0 to LQM.recordcount - 1 do
        LSOTicket.a['screenShots'].i[j] := LQM.geti(j, 'id');

    LSOTickets.O['getUserMessages'].a['tickets'].add(LSOTicket);
  end;
  moderators[io.ssid].writeln(LSOTickets.AsString);
end;

procedure TSupport.GetModerators(io: tioclass);
var
  LSO, LSOModerator: ISuperObject;
  i: int32;
begin
  LSO := SO;
  LSO.O['getModerators'] := SO;
  LSO.O['getModerators'].O['moderators'] := SA([]);
  with Query('SELECT moderators.id, moderators.login, moderators.firstName, AVG(Estimate.Stars) AS AverageScore ' +
    'FROM moderators LEFT JOIN Estimate on moderators.id = Estimate.ModeratorId ' +
    'GROUP BY moderators.id, moderators.login, moderators.firstName ', []) do
  begin
    for i := 0 to recordcount - 1 do
    begin
      LSOModerator := SO;
      LSOModerator.i['id'] := geti(i, 'id');
      LSOModerator.s['login'] := getS(i, 'Login', '');
      LSOModerator.s['name'] := getS(i, 'FirstName', '');
      LSOModerator.s['averageScore'] := getS(i, 'AverageScore', '0.0');
      LSO.O['getModerators'].A['moderators'].Add(LSOModerator);
    end;
  end;
  moderators[io.ssid].writeln(LSO.AsString);
end;

procedure TSupport.GetModeratorResponseTikets(io: tioclass);
var
  LSO, LSOTikcet: ISuperObject;
  i: int32;
begin
  LSO := SO;
  LSO.O['responseTikets'] := SO;
  LSO.O['responseTikets.messages'] := SA([]);
  try
    with Query('EXEC GetModeratorResponseTikets @ModerId = :ModerId, @Stars = :Stars, @DateFrom = :DateFrom, @DateTo = :DateTo',
      [io.iSO.i['id'], io.iSO.i['stars'], UnixToDateTime(io.iSO.i['timeFrom']), UnixToDateTime(io.iSO.i['timeTo'])]) do
      for i := 0 to recordcount - 1 do
      begin
        LSOTikcet := SO;
        LSOTikcet.i['id'] := geti(i, 'id');
        LSOTikcet.s['title'] := getS(i, 'title');
        LSOTikcet.O['owner'] := SO;
        LSOTikcet.i['owner.socialid'] := geti(i, 'social_id');
        LSOTikcet.s['owner.viewerid'] := getS(i, 'viewer_id');
        LSOTikcet.s['owner.firstName'] := getS(i, 'firstName');
        LSOTikcet.s['owner.lastName'] := getS(i, 'lastName');
        LSOTikcet.i['owner.userid'] := geti(i, 'userId', -1);
        LSOTikcet.i['createTime'] := DateTimeToUnix(getd(i, 'createTime'));
        LSOTikcet.B['favorite'] := boolean(geti(i, 'favorite'));
        LSOTikcet.i['lastUpdate'] := DateTimeToUnix(getd(i, 'lastUpdate'));
        LSOTikcet.s['clientVersion'] := getS(i, 'Version', '');
        LSOTikcet.s['deviceName'] := getS(i, 'Device', '');
        LSOTikcet.B['isDonator'] := boolean(geti(i, 'isDonator', 0));
        LSOTikcet.s['type'] := getS(i, 'type');
        LSOTikcet.s['state'] := getS(i, 'state');
        LSOTikcet.i['game_id'] := geti(i, 'game_id');
        LSOTikcet.s['language'] := getS(i, 'language');
        LSO.a['responseTikets.messages'].add(LSOTikcet);
      end;
    LSO.i['responseTikets.status'] := 1;
  except
    on E: Exception do
    begin
      LSO.i['responseTikets.status'] := 0;
    end;
  end;
  moderators[io.ssid].writeln(LSO.AsString);
end;

procedure TSupport.GetModeratorMessages(io: tioclass);
var
  id: int32;
begin
  id := io.iSO.i['id'];
  moderators.messagesArray(io.ssid, id, 'moderatorMessages');
end;

procedure TSupport.ReadTicket(io: tioclass);
var
  title, message_, firstName, lastName: string;
  auth_key, viewer_id, server_key: string;
  q: IQuery;
  tempmoderator: TModerator;
  id, type_id, soc_id, i, j, game_id: int32;
begin
  auth_key := io.iSO.s['auth_key'];
  viewer_id := io.iSO.s['viewer_id'];
  server_key := io.iSO.s['server_key'];
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
  io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
  io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
  io.client.writeheaderhttp('Content-Type: text/html; charset=UTF-8');
  io.client.writeheaderhttp('Content-Type, X-Requested-With, X-File-Size, X-File-Name');
  io.client.writeheaderhttp('Content-Type:application/json; charset=UTF-8');

  // if not(checkuser(server_key, viewer_id)) then
  // begin
  // io.client.writelnHTTPNH('Попробуйте зайти в игру из другого браузера или опишите проблему в группе.');
  // exit;
  // end;
  try
    QueryExec('update messageList set state_id = 4 where id=:id', [io.iSO.i['id']]);
  except
    on E: Exception do
    begin
      io.client.writelnHTTPNH('{"readTicket":{"status":0}}');
      exit;
    end;
  end;
  io.client.writelnHTTPNH('{"readTicket":{"status":1}}');
  q := nil;
end;

procedure TSupport.Response(io: tioclass);
var
  id: int32;
  message_: string;
begin
  id := io.iSO.i['id'];
  message_ := io.iSO.s['message'];
  moderators.updateMessage(io.ssid, id, message_);
end;

procedure TSupport.SetFavorite(io: tioclass);
var
  id: int32;
  type_: boolean;
begin
  id := io.iSO.i['id'];
  type_ := io.iSO.B['type'];
  moderators.updateMessage(io.ssid, id, type_);
end;

procedure TSupport.SetClose(io: tioclass);
begin
  try
    QueryExec('update messageList set state_id=3 where id=:id', [io.iSO.i['id']]);
  except
    on E: Exception do
    begin
      moderators.moderators[io.ssid].writeln('{"closeMessage":{"status":0}}');
      exit
    end;
  end;
  moderators.messages(io.iSO.i['id']);
end;

procedure TSupport.GetMessageAt(io: tioclass);
begin
  moderators.messageAt(io.ssid, io.iSO.i['next'], io.iSO.i['back'], io.iSO.i['state'], Integer(io.iSO.B['favorite']));
end;

procedure TSupport.GetMessageList(io: tioclass);
var
  soc_id: string;
  auth_key, viewer_id, server_key: string;
  func: string;
  q: IQuery;
  js: ISuperObject;
  ml: ISuperObject;
  i, game_id: int32;
begin
  auth_key := io.iSO.s['auth_key'];
  viewer_id := io.iSO.s['viewer_id'];
  server_key := io.iSO.s['server_key'];
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
  io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
  io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
  io.client.writeheaderhttp('Content-Type: text/html; charset=UTF-8');

  if not(checkuser(server_key, viewer_id)) then
  begin
    io.client.writelnHTTPNH('Попробуйте зайти в игру из другого браузера или опишите проблему в группе.');
    exit;
  end;
  soc_id := io.iSO.s['social_id'];
  game_id := io.iSO.i['game_id'];
  func := io.iSO.s['jsonp_messageList'];
  js := SO;
  try
    q := Query('exec getMessageListToUser @viewer_id=:viewer_id, @social_id=:social_id,@game_id=:game_id', [viewer_id, soc_id, game_id]);

    if q.recordcount > 0 then
    begin
      js.O['messageList'] := SA([]);
      for i := 0 to q.recordcount - 1 do
      begin
        ml := SO;
        ml.i['id'] := q.geti(i, 'id');
        ml.s['title'] := q.getS(i, 'title');
        ml.s['viewer_id'] := q.getS(i, 'viewer_id');
        ml.i['social_id'] := q.geti(i, 'social_id');
        ml.s['firstName'] := q.getS(i, 'firstName');
        ml.s['lastName'] := q.getS(i, 'lastName');
        ml.i['createTime'] := DateTimeToUnix(q.getd(i, 'createTime'));
        ml.s['type'] := q.getS(i, 'type');
        ml.s['state'] := q.getS(i, 'state');
        ml.i['count'] := q.geti(i, 'count');
        ml.i['stars'] := q.geti(i, 'stars', 0);
        js.a['messageList'].add(ml);
      end;
      q := nil;
      js.i['status'] := 1;
    end;
  except
    on E: Exception do
      js.i['status'] := 0;
  end;
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Content-Type, X-Requested-With, X-File-Size, X-File-Name');
  io.client.writeheaderhttp('Content-Type:application/json; charset=UTF-8');
  if func <> '' then
    io.client.writelnHTTPNH(func + '(' + js.AsString + ' );')
  else
    io.client.writelnHTTPNH(js.AsString);

end;

procedure TSupport.DeleteMessage(io: tioclass);
var
  tempmoderator: TModerator;
  id: int32;
begin
  id := io.iSO.i['id'];
  try
    if moderators.moderators[io.ssid].access = 1 then
    begin
      QueryExec('delete from messageList where id=:id', [id]);
      for tempmoderator in moderators.moderators.Values do
        tempmoderator.writeln('{"deleteMessage":{"id":' + inttostr(id) + ',"status":1}}');
    end
    else
      moderators.moderators[io.ssid].writeln('{"deleteMessage":{"status":"У Вас нет прав на удаление сообщений!"}}');
  except
    on E: Exception do
    begin
      moderators.moderators[io.ssid].writeln('{"deleteMessage":{"status":0}}');
      exit;
    end;
  end;
end;

procedure TSupport.FindMessage(io: tioclass);
var
  id: int32;
begin
  id := io.iSO.i['id'];
  moderators.FindMessage(io.ssid, id);
end;

procedure TSupport.DelImage(io: tioclass);
var
  func: string;
  auth_key, viewer_id, server_key: string;
begin
  auth_key := io.iSO.s['auth_key'];
  viewer_id := io.iSO.s['viewer_id'];
  server_key := io.iSO.s['server_key'];
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
  io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
  io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
  io.client.writeheaderhttp('Content-Type: text/html; charset=UTF-8');

  if not(checkuser(server_key, viewer_id)) then
  begin
    io.client.writelnHTTPNH('Попробуйте зайти в игру из другого браузера или опишите проблему в группе.');
    exit;
  end;
  try
    func := io.iSO.s['jsonp_delImage'];
    screen := screenShotPool.Items[io.iSO.i['id']];
    screenShotPool.Remove(io.iSO.i['id']);
    Finalize(screen.screenshot);
    FreeAndNil(screen);
    io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
    io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
    io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
    io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
    io.client.writeheaderhttp('Content-Type: application/json; charset=UTF-8');
    io.client.writeheaderhttp('Connection:close');
    io.client.writelnHTTPNH(func + '({"status":1})');
  except
    on E: Exception do
      io.client.writelnHTTPNH(func + '({"status":0})');

  end;

end;

procedure TSupport.EstimateTiket(io: tioclass);
var
  viewer_id, server_key: string;
begin
  viewer_id := io.iSO.s['viewer_id'];
  server_key := io.iSO.s['server_key'];
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
  io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
  io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
  io.client.writeheaderhttp('Content-Type: text/html; charset=UTF-8');

  if not(checkuser(server_key, viewer_id)) then
  begin
    io.client.writelnHTTPNH('Попробуйте зайти в игру из другого браузера или опишите проблему в группе.');
    exit;
  end;
  try
    if (io.iSO.i['stars'] < 0) or (io.iSO.i['stars'] > 5) then
      exit;
    QueryExec('EXEC EstimateTiket @Id=:Id, @Stars=:Stars ',
      [io.iSO.i['id'], io.iSO.i['stars']]);
  except
    on E: Exception do
      io.client.writelnHTTPNH('{"estimateTiket":{"status":0}}');
  end;
end;

procedure TSupport.GetChainofMessages(io: tioclass);
var
  func: string;
  auth_key, viewer_id, server_key: string;
  id: int32;
  ql: IQuery;
  messages: ISuperObject;
  ml: ISuperObject;
  i: int32;
  Lmessage: string;
begin
  auth_key := io.iSO.s['auth_key'];
  viewer_id := io.iSO.s['viewer_id'];
  server_key := io.iSO.s['server_key'];
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
  io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
  io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
  io.client.writeheaderhttp('Content-Type: text/html; charset=UTF-8');

  if not(checkuser(server_key, viewer_id)) then
  begin
    io.client.writelnHTTPNH('Попробуйте зайти в игру из другого браузера или опишите проблему в группе.');
    exit;
  end;
  id := io.iSO.i['id'];
  func := io.iSO.s['jsonp_message'];
  i := io.client.ssid;
  try
    ml := SO;
    ml.O['messages'] := SA([]);
    ql := tquery.create('exec getMessagesUser @id=:id', [id]);
    if ql.recordcount > 0 then
      for i := 0 to ql.recordcount - 1 do
      begin
        messages := SO;
        messages.i['id'] := ql.geti(i, 'id');
        messages.s['from'] := ql.getS(i, 'from_');
        messages.s['type'] := ql.getS(i, 'type');
        Lmessage := StringReplace(ql.getS(i, 'message'), chr(10), ' ', [rfReplaceAll, rfIgnoreCase]);
        messages.s['message'] := StringReplace(Lmessage, chr(13), ' ', [rfReplaceAll, rfIgnoreCase]);
        messages.i['time'] := DateTimeToUnix(ql.getd(i, 'time'));
        ml.a['messages'].add(messages);
      end;
    ml.i['status'] := 1;
  except
    on E: Exception do
      ml.i['status'] := 0;
  end;
  io.client.writeheaderhttp('Content-Type:application/json; charset=UTF-8');
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Content-Type, X-Requested-With, X-File-Size, X-File-Name');
  io.client.writeheaderhttp('Content-Type:application/json; charset=UTF-8');

  if func <> '' then
    io.client.writelnHTTPNH(func + '(' + ml.AsString + ' );')
  else
    io.client.writelnHTTPNH(ml.AsString);
end;

procedure TSupport.SetMessageList(io: tioclass);
var
  firstName, lastName: string;
  viewer_id, server_key: string;
  q: IQuery;
  tempmoderator: TModerator;
  id, i, j: int32;
  func: string;
  language: string;
  UserId: int32;
  Lmessage: string;
  isDonator: boolean;
  LVersion: string;
  LDevice: string;
begin
  viewer_id := io.iSO.s['viewer_id'];
  server_key := io.iSO.s['server_key'];
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
  io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
  io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
  io.client.writeheaderhttp('Content-Type: text/html; charset=UTF-8');

  if not(checkuser(server_key, viewer_id)) then
  begin
    io.client.writelnHTTPNH('Попробуйте зайти в игру из другого браузера или опишите проблему в группе.');
    exit;
  end;
  func := io.iSO.s['jsonp_setMessageList'];
  firstName := io.iSO.s['firstName'];
  lastName := io.iSO.s['lastName'];
  language := io.iSO.s['language'];
  isDonator := io.iSO.B['isDonator'];
  LVersion := io.iSO.s['clientVersion'];
  LDevice := io.iSO.s['deviceName'];

  if Length(language) = 0 then
    language := 'null';

  UserId := IfThen(io.iSO.i['user_id'] > 0, io.iSO.i['user_id'], -1);
  if firstName = '' then
    firstName := 'Username';
  // if lastName = '' then
  // lastName := 'UserLastName';
  Lmessage := StringReplace(io.iSO.s['message'], chr(10), ' ', [rfReplaceAll, rfIgnoreCase]);
  Lmessage := StringReplace(Lmessage, chr(13), ' ', [rfReplaceAll, rfIgnoreCase]);
  try
    q := Query('exec SetMessageList @viewer_id=:viewer_id,@social_id=:social_id,' +
      '@firstName=:firstName, @lastName=:lastName,@title=:title,@createTime=:createTime,' +
      '@type_id=:type_id,@game_id=:game_id,@message=:message,@screen_link=:screen_link, @userId=:uid, @lang=:l, @isDonator=:isDonator, @DeviceName=:Device, @ClientVersion=:Version',
      [viewer_id, io.iSO.i['social_id'], firstName,
      lastName, io.iSO.s['title'],
      now, io.iSO.i['type_id'], io.iSO.i['game_id'], Lmessage, io.iSO.s['screen_link'], UserId, language, isDonator, LVersion, LDevice]);
    id := q.geti(0, 'id');
    // setscreenShot
    if io.iSO.a['screenShot_id'] <> nil then
      for i := 0 to io.iSO.a['screenShot_id'].Length - 1 do
      begin
        j := io.iSO.a['screenShot_id'].i[i];
        QueryExec('exec setImage @screenShot=:screenShot,@messageList_id=:messageList_id',
          [screenShotPool.Items[io.iSO.a['screenShot_id'].i[i]].screenshot, id]);
        screen := screenShotPool.Items[io.iSO.a['screenShot_id'].i[i]];
        screenShotPool.Remove(io.iSO.a['screenShot_id'].i[i]);
        Finalize(screen.screenshot);
        FreeAndNil(screen);
        q := nil;
      end;
  except
    on E: Exception do
    begin
      if func <> '' then
        io.client.writelnHTTPNH(func + '({"status":0} );')
      else
        io.client.writelnHTTPNH('{"setMessageList":{"status":0}};');
      exit;
    end;
  end;
  if func <> '' then
    io.client.writelnHTTPNH(func + '({"status":1} );')
  else
    io.client.writelnHTTPNH('{"setMessageList":{"status":1}};');

  q := nil;
  moderators.messages(id);
end;

procedure TSupport.SetMessage(io: tioclass);
var
  q: IQuery;
  tempmoderator: TModerator;
  func: string;
  auth_key, viewer_id, server_key, Lmessage: string;
begin
  auth_key := io.iSO.s['auth_key'];
  viewer_id := io.iSO.s['viewer_id'];
  server_key := io.iSO.s['server_key'];
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
  io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
  io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
  io.client.writeheaderhttp('Content-Type: text/html; charset=UTF-8');

  if not(checkuser(server_key, viewer_id)) then
  begin
    io.client.writelnHTTPNH('Попробуйте зайти в игру из другого браузера или опишите проблему в группе.');
    exit;
  end;
  func := io.iSO.s['jsonp_setMessage'];
  io.client.writeheaderhttp('Content-Type:application/json; charset=UTF-8');
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Content-Type, X-Requested-With, X-File-Size, X-File-Name');
  io.client.writeheaderhttp('Content-Type:application/json');
  Lmessage := StringReplace(io.iSO.s['message'], chr(10), ' ', [rfReplaceAll, rfIgnoreCase]);
  Lmessage := StringReplace(Lmessage, chr(13), ' ', [rfReplaceAll, rfIgnoreCase]);
  try
    q := Query('exec SetMessageUser @id=:id,@message=:message,@Time_=:Time_', [io.iSO.i['id'], Lmessage, now]);
    q := nil;
  except
    on E: Exception do
    begin
      if func <> '' then
        io.client.writelnHTTPNH(func + '({"status":0});')
      else
        io.client.writelnHTTPNH('{"setMessage":{"status":0}};');
      exit;
    end;
  end;
  io.client.writeheaderhttp('Connection:close');
  if func <> '' then
    io.client.writelnHTTPNH(func + '({"status":1});')
  else
    io.client.writelnHTTPNH('{"setMessage":{"status":1}};');
  moderators.messages(io.iSO.i['id']);
end;

procedure TSupport.GetID(io: tioclass);
var
  temp: Tscreenpool;
  func: string;
  jfunc: string;
  auth_key, viewer_id, server_key: string;
begin
  auth_key := io.iSO.s['auth_key'];
  viewer_id := io.iSO.s['viewer_id'];
  server_key := io.iSO.s['server_key'];
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
  io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
  io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
  io.client.writeheaderhttp('Content-Type: text/html; charset=UTF-8');

  if not(checkuser(server_key, viewer_id)) then
  begin
    io.client.writelnHTTPNH('Попробуйте зайти в игру из другого браузера или опишите проблему в группе.');
    exit;
  end;
  func := io.iSO.s['unique_key'];
  jfunc := io.iSO.s['jsonp_getId'];
  try
    for temp in screenShotPool.Values do
      if func = temp.func then
      begin
        io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
        io.client.writeheaderhttp('Content-Type, X-Requested-With, X-File-Size, X-File-Name');
        io.client.writeheaderhttp('Content-Type:application/json; charset=UTF-8');
        io.client.writelnHTTPNH(jfunc + '({"id":' + inttostr(temp.id) + '})');
      end;
  finally

  end;
end;

{ procedure tsupport.getImage(io: tioclass);
  var
  qscreen: iquery;
  begin
  qscreen := query('exec getImages @id=:id', [io.iSO.i['id']]);
  if qscreen.recordcount > 0 then
  begin
  io.client.writeheaderhttp('Content-Type:application/json; charset=UTF-8');
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp
  ('Content-Type, X-Requested-With, X-File-Size, X-File-Name');
  io.client.writeheaderhttp('Content-Type:image/jpeg charset=UTF-8');
  io.client.writelnHTTPNH(tstringstream.create(qscreen.getS(0, 'screenShot')));
  end;
  end; }

procedure TSupport.SetImage(io: tioclass);
var
  auth_key, viewer_id, server_key: string;

  func: string;
  tempscreenShot: string;
  SS, ss1: tstringstream;
  Count: int32;
  jpg: TJPEGImage;
  Bitmap: TBitmap;

begin
  Bitmap := nil;
  jpg := nil;
  SS := nil;
  ss1 := nil;
  auth_key := io.iSO.s['auth_key'];
  viewer_id := io.iSO.s['viewer_id'];
  server_key := io.iSO.s['server_key'];
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
  io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
  io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
  io.client.writeheaderhttp('Content-Type: text/html; charset=UTF-8');

  if not(checkuser(server_key, viewer_id)) then
  begin
    io.client.writelnHTTPNH('Попробуйте зайти в игру из другого браузера или опишите проблему в группе.');
    exit;
  end;
  try
    screen := Tscreenpool.create;
    SS := tstringstream.create('');
    SS.LoadFromStream(io.httpstream);
    tempscreenShot := SS.DataString;

    if AnsiPos('Content-Disposition: form-data; name="unique_key:', tempscreenShot) <> 0 then
      delete(tempscreenShot, 1, AnsiPos('unique_key', tempscreenShot) + Length('unique_key'));
    Count := AnsiPos('"', tempscreenShot) - 1;
    screen.func := Copy(tempscreenShot, 1, Count);

    delete(tempscreenShot, 1, AnsiPos('Content-Type', tempscreenShot) - 1);
    delete(tempscreenShot, AnsiPos('Content-Type', tempscreenShot), AnsiPos(#$A, tempscreenShot));
    delete(tempscreenShot, AnsiPos(#$D#$A, tempscreenShot), AnsiPos(#$A, tempscreenShot));
    delete(tempscreenShot, AnsiPos('----', tempscreenShot), AnsiPos(#$A, tempscreenShot));
    ss1 := tstringstream.create(tempscreenShot);
    if (tempscreenShot[1] = 'B') and (tempscreenShot[2] = 'M') then
    begin
      try
        jpg := TJPEGImage.create;
        Bitmap := TBitmap.create;
        begin
          Bitmap.LoadFromStream(ss1);
          jpg.Assign(Bitmap);
          jpg.SaveToStream(SS);
          tempscreenShot := SS.DataString;
        end;
      finally
        if Assigned(jpg) then
          FreeAndNil(jpg);
        if Assigned(Bitmap) then
          FreeAndNil(Bitmap);
      end;
    end;
    if screenShotPool.Count = 0 then
      max_id_screen := 1
    else
      inc(max_id_screen);
    screen.id := max_id_screen;

    if SS.size > 5000000 then
      try
        jpg := TJPEGImage.create;
        Bitmap := TBitmap.create;
        begin
          jpg.LoadFromStream(ss1);
          Bitmap.Assign(jpg);
          if Bitmap.Width > 1024 then
            ResizeBmp(Bitmap, 1024, 1024);
          jpg.Assign(Bitmap);
          jpg.SaveToStream(SS);
          tempscreenShot := SS.DataString;
          if Assigned(jpg) then
            FreeAndNil(jpg);
          if Assigned(Bitmap) then
            FreeAndNil(Bitmap);
        end;
      except
        on E: Exception do
        begin
          Bitmap.LoadFromStream(ss1);
          if Bitmap.Width > 1024 then
            ResizeBmp(Bitmap, 1024, 1024);
          jpg.Assign(Bitmap);
          jpg.SaveToStream(SS);
          tempscreenShot := SS.DataString;
          if Assigned(jpg) then
            FreeAndNil(jpg);
          if Assigned(Bitmap) then
            FreeAndNil(Bitmap);
        end;
      end;
    screen.screenshot := tempscreenShot;
    screen.time := now;
    screenShotPool.add(max_id_screen, screen);
    io.client.writelnHTTPNH(inttostr(max_id_screen));
    if Assigned(SS) then
      FreeAndNil(SS);
    if Assigned(ss1) then
      FreeAndNil(ss1);
    if Assigned(Bitmap) then
      FreeAndNil(Bitmap);
    if Assigned(jpg) then
      FreeAndNil(jpg);
    Finalize(tempscreenShot);
    screen.screenNotification := scheduler.AddSchedule(425000, screen.screenDeletePool, ttpNormal, 'screen.screenDeletePool');
  except
    on E: Exception do
    begin
      io.client.writelnHTTPNH(func + '{"status":0}');
      if Assigned(SS) then
        FreeAndNil(SS);
      if Assigned(ss1) then
        FreeAndNil(ss1);
      if Assigned(Bitmap) then
        Bitmap.Destroy;
      if Assigned(jpg) then
        jpg.Destroy;
      pointer(tempscreenShot) := nil;
      if Assigned(screen) then
        Finalize(screen.screenshot);
      FreeAndNil(screen);
    end;
  end;
end;

procedure TSupport.SetScreenShot(io: tioclass);
var
  auth_key, viewer_id, server_key: string;

  func: string;
  SS, ss1: tstringstream;
  Count: int32;
  jpg: TJPEGImage;
  Bitmap: TBitmap;

begin
  auth_key := io.iSO.s['auth_key'];
  viewer_id := io.iSO.s['viewer_id'];
  server_key := io.iSO.s['server_key'];
  io.client.writeheaderhttp('Access-Control-Allow-Origin: *');
  io.client.writeheaderhttp('Access-Control-Allow-Credentials: true');
  io.client.writeheaderhttp('Access-Control-Allow-Methods: OPTIONS, HEAD, GET, POST');
  io.client.writeheaderhttp('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-File-Type, X-File-Size');
  io.client.writeheaderhttp('Content-Type: text/html; charset=UTF-8');

  if not(checkuser(server_key, viewer_id)) then
  begin
    io.client.writelnHTTPNH('Попробуйте зайти в игру из другого браузера или опишите проблему в группе.');
    exit;
  end;
  try
    Bitmap := nil;
    jpg := nil;
    screen := Tscreenpool.create;
    SS := tstringstream.create('');
    SS.LoadFromStream(io.httpstream);
    screen.screenshot := SS.DataString;
    if AnsiPos('Content-Disposition: form-data; name="unique_key:', screen.screenshot) <> 0 then
      delete(screen.screenshot, 1, AnsiPos('unique_key', screen.screenshot) + Length('unique_key'));
    Count := AnsiPos('"', screen.screenshot) - 1;
    screen.func := Copy(screen.screenshot, 1, Count);
    delete(screen.screenshot, 1, AnsiPos('Content-Type', screen.screenshot) - 1);
    delete(screen.screenshot, AnsiPos('Content-Type', screen.screenshot), AnsiPos(#$A, screen.screenshot));
    delete(screen.screenshot, AnsiPos(#$D#$A, screen.screenshot), AnsiPos(#$A, screen.screenshot));
    delete(screen.screenshot, AnsiPos('----', screen.screenshot), AnsiPos(#$A, screen.screenshot));
    ss1 := tstringstream.create(screen.screenshot);
    if (screen.screenshot[1] = 'B') and (screen.screenshot[2] = 'M') then
    begin
      try
        jpg := TJPEGImage.create;
        Bitmap := TBitmap.create;
        begin
          Bitmap.LoadFromStream(ss1);
          jpg.Assign(Bitmap);
          jpg.SaveToStream(SS);
          screen.screenshot := SS.DataString;
        end;
      finally
        if Assigned(jpg) then
          FreeAndNil(jpg);
        if Assigned(Bitmap) then
          FreeAndNil(Bitmap);
      end;
    end;
    if screenShotPool.Count = 0 then
      max_id_screen := 1
    else
      inc(max_id_screen);
    screen.id := max_id_screen;
    screen.time := now;
    screenShotPool.add(max_id_screen, screen);
    io.client.writelnHTTPNH('{"setScreenShot":{"status":1,"id":' + inttostr(max_id_screen) + '}}');
    if Assigned(SS) then
      FreeAndNil(SS);
    if Assigned(ss1) then
      FreeAndNil(ss1);
    if Assigned(Bitmap) then
      FreeAndNil(Bitmap);
    if Assigned(jpg) then
      FreeAndNil(jpg);
    screen.screenNotification := scheduler.AddSchedule(425000, screen.screenDeletePool, ttpNormal, 'screen.screenDeletePool');
  except
    on E: Exception do
    begin
      io.client.writelnHTTPNH('{"setScreenShot":{"status":0}}');
      if Assigned(SS) then
        FreeAndNil(SS);
      if Assigned(ss1) then
        FreeAndNil(ss1);
      if Assigned(Bitmap) then
        FreeAndNil(Bitmap);
      if Assigned(jpg) then
        FreeAndNil(jpg);
    end;
  end;
end;

procedure Support_initialization;
begin
  support := TSupport.create;
  screenShotPool := TDictionary<int32, Tscreenpool>.create;

  cmdprocessor.AddCommand('/getMessageList.php', support.GetMessageList, 500, 300000, false);
  cmdprocessor.AddCommand('/getMessage.php', support.GetChainofMessages, 500, 300000, false);
  cmdprocessor.AddCommand('/getID.php', support.GetID, 500, 300000, false);
  cmdprocessor.AddCommand('/setMessageList.php', support.SetMessageList, 500, 300000, false);
  cmdprocessor.AddCommand('setMessageList', support.SetMessageList, 500, 300000, false);
  cmdprocessor.AddCommand('/setMessage.php', support.SetMessage, 500, 300000, false);
  cmdprocessor.AddCommand('/readTicket.php', support.ReadTicket, 500, 300000, false);
  cmdprocessor.AddCommand('/unReadTiketCount.php', support.UnReadTiketCount, 500, 300000, false);
  { cmdprocessor.AddCommand('/getImage.php', support.getImage, 500,
    300000, false); }
  cmdprocessor.AddCommand('/setImage.php', support.SetImage, 500, 300000, false);
  cmdprocessor.AddCommand('/setScreenShot.php', support.SetScreenShot, 500, 300000, false);
  cmdprocessor.AddCommand('/delImage.php', support.DelImage, 500, 300000, false);
  cmdprocessor.AddCommand('/estimateTiket.php', support.EstimateTiket, 500, 300000, false);

  cmdprocessor.AddCommand('userAuth', support.Support_auth, 500, 300000, false);
{$IFDEF Debug}
  cmdprocessor.AddCommand('/userAuth.php', support.Supportauth, 500, 300000, false);
{$ENDIF}
  cmdprocessor.AddCommand('getMessages', support.GetMessages, 500, 300000, true);
  cmdprocessor.AddCommand('findMessage', support.FindMessage, 500, 300000, true);
  cmdprocessor.AddCommand('getMessageAt', support.GetMessageAt, 500, 300000, true);

  cmdprocessor.AddCommand('response', support.Response, 500, 300000, true);
  cmdprocessor.AddCommand('setFavorite', support.SetFavorite, 500, 300000, true);
  cmdprocessor.AddCommand('getScreenShot', support.GetScreenShot, 500, 300000, true);
  cmdprocessor.AddCommand('closeMessage', support.SetClose, 500, 300000, true);
  cmdprocessor.AddCommand('deleteMessage', support.DeleteMessage, 500, 300000, true);
  cmdprocessor.AddCommand('access', support.UpdateAccess, 500, 300000, true);
  cmdprocessor.AddCommand('getUserMessages', support.GetUserMessages, 500, 300000, true);
  cmdprocessor.AddCommand('getUserMessagesFromUserId', support.GetUserMessagesFromUserId, 500, 300000, true);
  // admin
  cmdprocessor.AddCommand('getModerators', support.GetModerators, 500, 300000, true);
  cmdprocessor.AddCommand('getModeratorResponseTikets', support.GetModeratorResponseTikets, 500, 300000, True);
  cmdprocessor.AddCommand('getModeratorMessages', support.GetModeratorMessages, 500, 300000, true);

  log.System('Commands initialized: ' + inttostr(cmdprocessor.Count) + ' commands.', true);

end;

procedure Support_finalization;
begin

end;

initialization

finalization

FreeAndNil(support);

end.
