unit uModerator;

interface

uses uClient, uSocialClasses, classes,
  generics.Collections, usocketcommands,
  OverbyteIcsWSocketTS, OverbyteIcsWSocket, OverbyteIcsWSockBuf, sysutils, windows, uDBManager;

type
  taccess = class
  strict private
    FLanguage: string;
    FGameId: int32;
    FSocialID: int32;

  public
    function check(const AGame, ASocial: int32; const ALanguage: string): Boolean;
    constructor Create(const AGame, ASocial: int32; const ALanguage: string);
    destructor Destroy; override;
  end;

  TAccessList = class(TList<taccess>)
    constructor Create(const AModerId: int32);
    destructor Destroy; override;
    function CheckAccess(const AGame, ASocial: int32; const ALanguage: string): Boolean;
  end;

  tModerator = class
  private
    fClient: iclient;

  public
    id, access: int32;
    firstName, lastname: string;
    AccessLGS: TAccessList;
    procedure writeln(str: string; isAnsi: Boolean = false);
    constructor Create;
    property client: iclient read fClient write fClient;
  end;

implementation

uses ulogicthreads, uioclasses, udebug, ulog, superobject,
  idexception, uzipcompressor;

procedure tModerator.writeln(str: string; isAnsi: Boolean = false);
begin
  fClient.write(str, isAnsi);
end;

function TAccessList.CheckAccess(const AGame, ASocial: int32; const ALanguage: string): Boolean;
var
  LAccess: taccess;
begin
  Result := false;
  for LAccess in self do
    if LAccess.check(AGame, ASocial, ALanguage) then
      Exit(True);
end;

constructor tModerator.Create;
begin
  fClient := nil;
  id := 0;
  firstName := '';
  lastname := '';
end;

{ taccess }

function taccess.check(const AGame, ASocial: int32;
  const ALanguage: string): Boolean;
begin
  Result := ((FSocialID = ASocial) and (FGameId = AGame)) and ((FLanguage = ALanguage) or (ALanguage = '') or (ALanguage = 'null'));
//  if not Result then
//    log.Error('taccess.check');
end;

constructor taccess.Create(
  const
  AGame, ASocial: int32;
  const
  ALanguage:
  string);
begin
  FLanguage := ALanguage;
  FGameId := AGame;
  FSocialID := ASocial;
end;

destructor taccess.Destroy;
begin

  inherited;
end;

{ TAccessList }

constructor TAccessList.Create(
  const
  AModerId:
  int32);
var
  I: int32;
  Aquery: IQuery;
begin
  inherited Create;
  Aquery := query('select * from AccessGames WHERE UserId=:uid', [AModerId]);
  for I := 0 to Aquery.recordcount - 1 do
    if Aquery.getI(I, 'Hide', 0) <> 1 then
      Add(taccess.Create(Aquery.getI(I, 'GameId'), Aquery.getI(I, 'SocialId'), Aquery.gets(I, 'Language')));
end;

destructor TAccessList.Destroy;
begin

  inherited;
end;

end.
