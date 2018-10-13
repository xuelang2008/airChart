unit uMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons, Vcl.ExtCtrls,
  VCLTee.TeEngine, VCLTee.TeeProcs, VCLTee.Chart, VCLTee.TeCanvas, Vcl.ComCtrls,
  CPort, VCLTee.Series;

type
  TfrmMain = class(TForm)
    pnlRight: TPanel;
    pnlBottom: TPanel;
    Notebook1: TNotebook;
    Image1: TImage;
    Label1: TLabel;
    ListBox1: TListBox;
    btnSetup: TBitBtn;
    btnStart: TBitBtn;
    Chart1: TChart;
    Timer1: TTimer;
    Label2: TLabel;
    TrackBar1: TTrackBar;
    Label3: TLabel;
    Label4: TLabel;
    btnStop: TBitBtn;
    ComPort1: TComPort;
    Series1: TFastLineSeries;
    Series2: TFastLineSeries;
    Series3: TFastLineSeries;
    btn1: TButton;
    mmoDisplay: TMemo;
    Button2: TButton;
    procedure ListBox1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure btnSetupClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure ReadMeterData;
    function ComPortWrite(const Value: Word; buffer: array of Byte): Boolean;
    procedure ComPort1AfterClose(Sender: TObject);
    procedure ComPort1AfterOpen(Sender: TObject);
    procedure ComPort1Error(Sender: TObject; Errors: TComErrors);
    procedure ComPort1Exception(Sender: TObject; TComException: TComExceptions;
      ComportMessage: string; WinError: Int64; WinMessage: string);
    procedure btnStopClick(Sender: TObject);
    procedure btn1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    function BufToStr(Buf: array of Byte): String;
    procedure Display(Msg: String);
    function GetTheChart: TChart;
  protected
    function Ans(const Value: Word; buffer: array of Byte): Boolean;
    function Ans_0101(const buf: array of Byte): Boolean;
  public
    property TheChart: TChart read GetTheChart;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

function TfrmMain.Ans(const Value: Word; buffer: array of Byte): Boolean;
begin
  Display('Ans');
  Result := False;
end;

function TfrmMain.Ans_0101(const buf: array of Byte): Boolean;
begin
  Result := False;
end;

procedure TfrmMain.btn1Click(Sender: TObject);
begin
  ReadMeterData;
end;

procedure TfrmMain.btnSetupClick(Sender: TObject);
begin
  ComPort1.ShowSetupDialog;
end;

procedure TfrmMain.btnStartClick(Sender: TObject);
begin
  ComPort1.Open;
end;

procedure TfrmMain.btnStopClick(Sender: TObject);
begin
  ComPort1.Close;
end;

function TfrmMain.BufToStr(Buf: array of Byte): String;
var
  i: Integer;
begin
  for i := Low(Buf) to High(Buf) do
    Result := Result + IntToHex(Buf[i], 2) + ' ';
end;

procedure TfrmMain.Button2Click(Sender: TObject);
begin
  NoteBook1.PageIndex := 8;
end;

procedure TfrmMain.ComPort1AfterClose(Sender: TObject);
begin
  //在FormClose会报错，故加一层判断
  if Timer1 <> nil then
    Timer1.Enabled := False;
  if btnStop <> nil then
    btnStop.Enabled := False;
  if btnStart <> nil then
    btnStart.Enabled := True;
  if mmoDisplay <> nil then
    Display(Format('%s已关闭', [ComPort1.Port]));
end;

procedure TfrmMain.ComPort1AfterOpen(Sender: TObject);
begin
  Display(Format('%s已打开', [ComPort1.Port]));
  btnStart.Enabled := False;
  btnStop.Enabled := True;
  Timer1.Enabled := True;
end;

procedure TfrmMain.ComPort1Error(Sender: TObject; Errors: TComErrors);
begin
  Display('ComPortError' + ComErrorsToStr(Errors));
end;

procedure TfrmMain.ComPort1Exception(Sender: TObject;
  TComException: TComExceptions; ComportMessage: string; WinError: Int64;
  WinMessage: string);
begin
  Display('ComPortException' + WinMessage);
end;

function TfrmMain.ComPortWrite(const Value: Word;
  buffer: array of Byte): Boolean;
var
  AnsOK: Boolean;
  tickCount: Cardinal;
  Len, InputCount: Integer;
  ReceiveBuf: array of Byte;
begin
  try
    AnsOK := False;
    tickCount := 0;
    Application.ProcessMessages;
    ComPort1.Write(buffer, High(buffer) + 1);

    //串口返回超时时间2秒
    //代替ComPort.WaitForEvent(Events, 0, 2000);

    repeat
      Sleep(100);
      InputCount := ComPort1.InputCount;
      if InputCount > 0 then
      begin
        Len := Length(ReceiveBuf);
        SetLength(ReceiveBuf, Len + InputCount);

        ComPort1.Read(ReceiveBuf[Len], InputCount);
        AnsOK := Ans(Value, ReceiveBuf);
      end;
      Inc(tickCount);
      Application.ProcessMessages;
    until AnsOK or (tickCount >= 100);
  except
    on E: Exception do
      Display('Error: ' + E.Message);
  end;

  Result := AnsOK;
end;

procedure TfrmMain.Display(Msg: String);
var
  I : Integer;
begin
  mmoDisplay.Lines.BeginUpdate;
  try
    if mmoDisplay.Lines.Count > 200 then
    begin
      for I := 1 to 50 do
        mmoDisplay.Lines.Delete(0);
    end;
    mmoDisplay.Lines.Add(Msg);
  finally
    mmoDisplay.Lines.EndUpdate;
    SendMessage(mmoDisplay.Handle, EM_SCROLLCARET, 0, 0);
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  ListBox1.ItemIndex := 0;
  ListBox1Click(Self);
end;

procedure TfrmMain.ListBox1Click(Sender: TObject);
var
  t: Longint;
begin
  NoteBook1.PageIndex := ListBox1.ItemIndex;
//  With TheChart do
//  begin
//
//    for t:=0 to SeriesCount-1 do
//    With Series[t] do
//         FillSampleValues(NumSampleValues);
//
//  end;
end;

procedure TfrmMain.ReadMeterData;
var
  buf: array[0..9] of Byte;
  Rst: Boolean;
begin
  //读取终端序列号
  Display('');
  Display(' ==> 读取终端序列号');

  buf[0] := $7E; //标识位
  buf[1] := $00; //校验码
  buf[2] := $00; //版本号
  buf[3] := $01;
  buf[4] := $58; //厂商编号
  buf[5] := $5A;
  buf[6] := $F0; //外设类型编号
  buf[7] := $F2; //命令类型
  buf[8] := $04; //用户数据
  buf[9] := $7E; //标识位

  Rst := ComPortWrite($0101, buf);
  if not Rst then
    Display('接收超时：没有收到应答数据');

end;

function TfrmMain.GetTheChart: TChart;
begin
  with NoteBook1 do
    Result := (Pages.Objects[PageIndex] as TPage).Controls[0] as TChart;
end;

procedure TfrmMain.Timer1Timer(Sender: TObject);
var
  t: Longint;
  tmpX: Double;
begin
  //ReadMeterData;
    {
  With NoteBook1 do
  Case PageIndex of
     0,3,4,6:  With TheChart do
               begin
                 for t:=0 to SeriesCount-1 do
                 With Series[t] do
                 begin
                   tmpX:=XValues[1]-XValues[0];
                   Delete(0);
                   AddXY( XValues.Last+tmpX,
                          YValues.Last+Random(100)-50,'',clTeeColor);
                 end;
               end;   }
//          Chart1.BufferedDisplay := False;
//        Chart1.Tools.
//
//  With TheChart do
//  begin
//   for t:=0 to SeriesCount-1 do
//   With Series[t] do
//   begin
//
//     //Delete(0);
//     AddXY( Now,
//            Random(100)-50,'',clTeeColor);
//   end;
//  end;

//mmo1.Lines.Add(Format('GetMarkValue %.2f', [ Series1.GetMarkValue(Series1.GetCursorValueIndex)]));

//Series1.Active

end;

end.
