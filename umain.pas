unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Printers, EditBtn, Spin, ComCtrls, PrintersDlgs;

type
  { TFileTreeList }
  TFileTreeList = class;

  TFileTreeEntryType = ( etFile, etDirectory );
  TFileTreeEntry = packed record
    Name: string;
    Size: Int64;
    EntryType: TFileTreeEntryType;
    Entries: TFileTreeList;
  end;
  PFileTreeEntry = ^TFileTreeEntry;

  TFileTreeList = class(TFPList)
  private
    function Get(Index: integer): PFileTreeEntry;
  public
    destructor Destroy; override;
    function Add(ANote : PFileTreeEntry): integer;
    property Items[Index: integer]: PFileTreeEntry read Get; default;
  end;

  { TMain }

  TMain = class(TForm)
    btnPrint: TButton;
    btnScan: TButton;
    btnRedraw: TButton;
    chkPlusDate: TCheckBox;
    chkSize: TCheckBox;
    chkSideLabels: TCheckBox;
    CheckGroup1: TCheckGroup;
    edtSideLabel: TEdit;
    edtPath: TDirectoryEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    PaintBox1: TPaintBox;
    Panel1: TPanel;
    PrintDialog1: TPrintDialog;
    optFrontBack: TRadioButton;
    optDoubleFront: TRadioButton;
    pbWorking: TProgressBar;
    RadioGroup1: TRadioGroup;
    ScrollBox1: TScrollBox;
    edtMaxDirLevel: TSpinEdit;
    edtColumns: TSpinEdit;
    Splitter1: TSplitter;
    procedure btnPrintClick(Sender: TObject);
    procedure btnRedrawClick(Sender: TObject);
    procedure btnScanClick(Sender: TObject);
    procedure chkPlusDateChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure optDoubleFrontChange(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
  private
    FBitmap: TBitmap;
    FFilesBitmap: TBitmap;
    FPaperWidth: Integer;
    FPaperHeight: Integer;
    FTotalCount: Integer;
    FTree: TFileTreeList;
    FCellHeight: Integer;
    FMaxSizeWidth: Integer;
    procedure RenderFilesBitmap;
    function CmToX(cm: Double): Integer;
    function CmToY(cm: Double): Integer;
    function FilesToTree(Path: string; Pattern: string): TFileTreeList;
    function PrettyPrintSize(AValue: Int64): string;
  public

  end;

var
  Main: TMain;

implementation

{$R *.lfm}

uses Math;

const
  MaxFiles = 700;
  // Left/right margins
  LeftMargin = 30; TopMargin = 50;
  // A4 paper size in cm
  //A4PaperWidth = 21.0; A4PaperHeight = 29.7;
  A4PaperWidth = 29.7; A4PaperHeight = 21.0;
  PaperRatio = A4PaperWidth/A4PaperHeight;
  Tolarance=0.09;

function SortFileEntries(P1, P2: Pointer): Integer;
begin
  Result := AnsiCompareText(PFileTreeEntry(P1)^.Name, PFileTreeEntry(P2)^.Name);
end;

{ TFileTreeList }

function TFileTreeList.Get(Index: integer): PFileTreeEntry;
begin
  Result := PFileTreeEntry(inherited Get(index));
end;

destructor TFileTreeList.Destroy;
var
  I: Integer;
  P: PFileTreeEntry;
begin
  for I:=0 to Count-1 do begin
    P := PFileTreeEntry(Items[I]);
    if Assigned(P^.Entries) and (P^.EntryType = etDirectory) then
      P^.Entries.Free;
    Dispose(Items[I]);
  end;

  inherited Destroy;
end;

function TFileTreeList.Add(ANote: PFileTreeEntry): integer;
begin
  Result := inherited Add(ANote);
end;

{ TMain }

function TMain.CmToX(cm: Double): Integer;
begin
  Result := Round(FPaperWidth/A4PaperWidth*(cm));
end;

function TMain.CmToY(cm: Double): Integer;
begin
  Result := Round(FPaperHeight/A4PaperHeight*(cm+Tolarance));
end;

procedure TMain.PaintBox1Paint(Sender: TObject);
var
  C, R, Front2Rect, FrontRect, LeftRect, MiddleRect, RightRect: TRect;
  I, CopyHeight, NextTop: Integer;
begin
  with FBitmap do begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := clWhite;
    Canvas.FillRect(Rect(0,0,Width,Height));

    Canvas.Pen.Color := clBlack;
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Width := 1;

    FrontRect  := Bounds(LeftMargin,                                     TopMargin, CmToX(12.2), CmToY(12.0));
    Front2Rect := Bounds(LeftMargin+CmToX(12.2),                         TopMargin, CmToX(12.2), CmToY(12.0));

    LeftRect   := Bounds(LeftMargin+CmToX(13.0),                         TopMargin, CmToX( 0.6), CmToY(11.8));
    MiddleRect := Bounds(LeftMargin+CmToX(13.0)+CmToX( 0.6),             TopMargin, CmToX(13.8), CmToY(11.8));
    RightRect  := Bounds(LeftMargin+CmToX(13.0)+CmToX( 0.6)+CmToX(13.8), TopMargin, CmToX( 0.6), CmToY(11.8));

    if Assigned(FFilesBitmap) then begin
      Canvas.Brush.Style := bsClear;
      // Calculate height which can fit into FrontRect
      CopyHeight := FCellHeight * (FrontRect.Height div FCellHeight);
      NextTop := 0;

      // Render columns
      for I:=0 to edtColumns.Value-1 do begin
        if CopyHeight > FFilesBitmap.Height - NextTop then CopyHeight := FFilesBitmap.Height - NextTop;
        R := Bounds(
          FrontRect.Left+ I*(FrontRect.Width div edtColumns.Value),
          FrontRect.Top,
          FrontRect.Width div edtColumns.Value,
          CopyHeight
        );
        // Title
        Canvas.CopyRect(R, FFilesBitmap.Canvas, Bounds(0,NextTop,FrontRect.Width div edtColumns.Value,CopyHeight));
        if chkSize.Checked then begin
          // Size
          R.Left := R.Left + R.Width - FMaxSizeWidth; // Maybe I should put a small gap here on the right side
          R.Width := FMaxSizeWidth;
          Canvas.CopyRect(R, FFilesBitmap.Canvas, Bounds(FFilesBitmap.Canvas.Width-FMaxSizeWidth,NextTop,FMaxSizeWidth,CopyHeight));
        end;
        Inc(NextTop,CopyHeight);
      end;

      Canvas.Pen.Color := clSilver;
      Canvas.Pen.Style := psSolid;
      for I:=1 to edtColumns.Value-1 do begin
        Canvas.Line(
          FrontRect.Left + I*(FrontRect.Width div edtColumns.Value),
          FrontRect.Top,
          FrontRect.Left + I*(FrontRect.Width div edtColumns.Value),
          FrontRect.Top  + FrontRect.Height
        );
      end;

      // Calculate height which can fit into MiddleRect
      CopyHeight := FCellHeight * (MiddleRect.Height div FCellHeight);

      if optFrontBack.Checked then
        C := MiddleRect;
      if optDoubleFront.Checked then
        C := Front2Rect;

      // Render columns
      for I:=0 to edtColumns.Value-1 do begin
        if CopyHeight > FFilesBitmap.Height - NextTop then CopyHeight := FFilesBitmap.Height - NextTop;
        R := Bounds(
          C.Left+ I*(C.Width div edtColumns.Value),
          C.Top,
          C.Width div edtColumns.Value,
          CopyHeight
        );
        // Title
        Canvas.CopyRect(R, FFilesBitmap.Canvas, Bounds(0,NextTop,C.Width div edtColumns.Value,CopyHeight));
        if chkSize.Checked then begin
          // Size
          R.Left := R.Left + R.Width - FMaxSizeWidth; // Maybe I should put a small gap here on the right side
          R.Width := FMaxSizeWidth;
          Canvas.CopyRect(R, FFilesBitmap.Canvas, Bounds(FFilesBitmap.Canvas.Width-FMaxSizeWidth,NextTop,FMaxSizeWidth,CopyHeight));
        end;
        Inc(NextTop,CopyHeight);
      end;

      Canvas.Pen.Color := clSilver;
      Canvas.Pen.Style := psSolid;
      for I:=1 to edtColumns.Value-1 do begin
        Canvas.Line(
          C.Left + I*(C.Width div edtColumns.Value),
          C.Top,
          C.Left + I*(C.Width div edtColumns.Value),
          C.Top  + C.Height
        );
      end;
    end;

    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Color := clSilver;

    // Front: 12.2 cm x 12.0 cm
    Canvas.Rectangle(FrontRect);

    if optFrontBack.Checked then begin

      // Left: 0.6 cm x 11.5 cm
      Canvas.Rectangle(LeftRect);

      // Middle: 13.8 cm x 11.5 cm
      Canvas.Rectangle(MiddleRect);

      // Right: 0.6 cm x 11.5 cm
      Canvas.Rectangle(RightRect);

      Canvas.Brush.Style := bsClear;
      Canvas.Font.Size := 11;
      Canvas.Font.Color := clBlack;


      if chkSideLabels.Checked then begin

        // Left side label
        Canvas.Font.Orientation:=2700;
        Canvas.TextOut(
          CmToX(13.0) -2 + LeftMargin + CmToX(0.55),
          10 + TopMargin,
          edtSideLabel.Caption
        );

        // Right side label
        Canvas.Font.Orientation:=900;
        Canvas.TextOut(
          CmToX(13.0) + 3 + LeftMargin+ CmToX(13.8) + CmToX(0.6),
          -10 + TopMargin + CmToY(11.8),
          edtSideLabel.Caption
        );
      end;
    end;

    if optDoubleFront.Checked then begin
      // Back: 12.2 cm x 12.0 cm
      Canvas.Rectangle(Front2Rect);
    end;

    if optDoubleFront.Checked then begin
      Canvas.Pen.Color := clBlack;
      Canvas.Pen.Style := psDashDot;
      Canvas.Pen.Width := 1;
      Canvas.Line(
        Front2Rect.Left,
        -10 + Front2Rect.Top,
        Front2Rect.Left,
        Front2Rect.Top  + Front2Rect.Height + 10
      );
    end;

    Canvas.Font.Size := 16;
    Canvas.Font.Color := clSilver;
    Canvas.Font.Orientation:=0;
    Canvas.TextOut(
      LeftMargin + (FPaperWidth - Canvas.TextWidth(edtSideLabel.Caption)) div 2,
      TopMargin  + 2*(FPaperHeight div 3),
      edtSideLabel.Caption
    );
  end;

  PaintBox1.Canvas.Draw(0,0,FBitmap);
  // PaintBox1.Canvas.Draw(0,FBitmap.Height + 20,FBitmap);
end;

function TMain.PrettyPrintSize(AValue: Int64): string;
const
  Description: Array [0 .. 2] of string = ('B', 'KB', 'MB');
var
  i: Integer;
begin
  i := 0;

  while AValue > Power(1024, i + 1) do
    Inc(i);

  Result := FormatFloat('###0.##', AValue / IntPower(1024, i)) + ' ' + Description[i];
end;

procedure TMain.RenderFilesBitmap;
var
  BitmapWidth, BitmapHeight, CellTop, W: Integer;
  P: PFileTreeEntry;
  S: string;

  procedure RenderList(AList: TFileTreeList; Level: Integer);
  var
    I: Integer;
  begin
    with FFilesBitmap.Canvas do begin
      for I:=0 to AList.Count-1 do begin
        P := AList.Get(I);
        if P^.EntryType = etDirectory then
          Font.Style := Font.Style + [fsBold]
        else
          Font.Style := Font.Style - [fsBold];

        Brush.Style := bsClear;

        // Name
        TextOut(4+Level*8, CellTop, P^.Name);

        if P^.EntryType = etFile then begin
          // Size
          S := PrettyPrintSize(P^.Size);
          W := TextWidth(S);
          if W > FMaxSizeWidth then FMaxSizeWidth := W;
          TextOut(FFilesBitmap.Canvas.Width - W, CellTop, S);
        end;

        Pen.Color := clSilver;
        Line(0,Celltop + FCellHeight-1,BitmapWidth, CellTop + FCellHeight-1);
        CellTop := CellTop + FCellHeight;

        if (P^.EntryType = etDirectory) and Assigned(P^.Entries) then
           RenderList(P^.Entries, Level + 1);
      end;
    end;
  end;

begin
  FMaxSizeWidth := 0;

  WriteLn(Format('Total entries: %d, expected height: %d', [FTotalCount, -FBitmap.Canvas.Font.Height * FTotalCount]));
  if Assigned(FFilesBitmap) then
     FFilesBitmap.Free;

  BitmapWidth := FPaperWidth;
  BitmapHeight:= -FBitmap.Canvas.Font.Height*FTotalCount + 8;
  FFilesBitmap := TBitmap.Create;
  FFilesBitmap.SetSize(BitmapWidth, BitmapHeight);

  //WriteLn(Format('Files bitmap: %dx%d', [BitmapWidth, BitmapHeight]));

  with FFilesBitmap.Canvas do begin
    Brush.Color := clWhite;
    Brush.Style := bsSolid;
    FillRect(Rect(0,0,BitmapWidth,BitmapHeight));

    Font.Size := 8;
    // Calculate cell height
    FCellHeight:= -Font.Height + 4;

    CellTop := 0;
    RenderList(FTree, 0);
  end;
  WriteLn(Format('Total entries: %d, bitmap: %dx%d, size width: %d', [FTotalCount, BitmapWidth, BitmapHeight, FMaxSizeWidth]));

  //FFilesBitmap.SaveToFile(GetEnvironmentVariable('HOME') + '/Desktop/files.bmp');
end;

procedure TMain.FormCreate(Sender: TObject);
begin
  Width := 1380;
  Height := 820;

  FBitmap := TBitmap.Create;

  FPaperWidth :=  1123; // 794;
  FPaperHeight := 794; // 1123;
  //WriteLn(Format('Canvas size: %dx%d (%f) 12.2 cm -> %d, 12.0 cm -> %d',
  //  [FPaperWidth, FPaperHeight,PaperRatio, CmToX(12.2), CmToY(12.0)]));

  {
  with Printer.PaperSize do begin
    for I:=0 to SupportedPapers.Count-1 do begin
      WriteLn(Format('Paper size%d=%s',[I, SupportedPapers.ValueFromIndex[I]]));
    end;
  end;
  }

  // Set printer default to A4/Landscape
  Printer.PaperSize.PaperName:='A4';
  Printer.Orientation:=poLandscape;
  Printer.PaperSize.DefaultPaperName;

  with PaintBox1 do begin
    Width := FPaperWidth;
    Height := FPaperHeight; // (FPaperHeight * 2) + 50;
  end;
  FBitmap.SetSize(FPaperWidth,FPaperHeight);
  FBitmap.Canvas.FillRect(0,0,FBitmap.Width,FBitmap.Height);

  edtSideLabel.Caption := 'DATA'+FormatDateTime('yyyymmdd', Now);
end;

procedure TMain.btnPrintClick(Sender: TObject);
var
  MyPrinter: TPrinter;
begin
  if not PrintDialog1.Execute then Exit;

  MyPrinter := Printer;
  MyPrinter.Orientation:=poLandscape;

  with MyPrinter do begin
    CanvasClass:=TFilePrinterCanvas;
    BeginDoc;
    try
      Canvas.CopyRect(
        Rect(0,0,MyPrinter.PaperSize.Width, MyPrinter.PaperSize.Height),
        FBitmap.Canvas,
        Rect(0,0,FBitmap.Width, FBitmap.Height)
      );
    finally
      EndDoc;
    end;
  end;
end;

procedure TMain.btnRedrawClick(Sender: TObject);
begin
  PaintBox1.Repaint;
end;

procedure TMain.btnScanClick(Sender: TObject);
begin
  if Length(edtPath.Directory)=0 then Exit;

  if Assigned(FTree) then
     FTree.Free;

  FTree := FilesToTree(edtPath.Directory, '*');
  RenderFilesBitmap;

  edtSideLabel.Caption := ExtractFileName(edtPath.Directory);
  if chkPlusDate.Checked then
    edtSideLabel.Caption := edtSideLabel.Caption +'-'+FormatDateTime('yyyymmdd', Now);

  PaintBox1.Repaint;
end;

procedure TMain.chkPlusDateChange(Sender: TObject);
begin
  edtSideLabel.Caption := ExtractFileName(edtPath.Directory);
  if chkPlusDate.Checked then
    edtSideLabel.Caption := edtSideLabel.Caption +'-'+FormatDateTime('yyyymmdd', Now);
end;

procedure TMain.FormDestroy(Sender: TObject);
begin
  if Assigned(FBitmap) then
     FBitmap.Free;

  if Assigned(FFilesBitmap) then
     FFilesBitmap.Free;

  if Assigned(FTree) then
     FTree.Free;
end;

procedure TMain.optDoubleFrontChange(Sender: TObject);
begin
  PaintBox1.Repaint;
end;

function TMain.FilesToTree(Path: string; Pattern: string): TFileTreeList;

  function FindFiles(Path, Pattern: string; Level: Integer): TFileTreeList;
  var
    Rec: TSearchRec;
    DirList: TFileTreeList;
    DirNode, FileNode: PFileTreeEntry;
    SearchPath: string;
  begin
    DirList := TFileTreeList.Create;
    SearchPath := IncludeTrailingBackslash(Path);
    if FindFirst(SearchPath + Pattern, faAnyFile - faDirectory, Rec) = 0 then
    begin
      try
        repeat
          Application.ProcessMessages;
          New(FileNode);
          with FileNode^ do begin
            EntryType:=etFile;
            Name:=Rec.Name;
            Size:=Rec.Size;
            Entries:=nil;
          end;
          DirList.Add(FileNode);
          Inc(FTotalCount);
          //WriteLn(DupeString('-', Level) + FileNode^.Name);
        until (FindNext(Rec) <> 0) or (FTotalCount >= MaxFiles);
      finally
        FindClose(Rec);
      end;
    end;
    if FTotalCount < MaxFiles then begin
      if FindFirst(SearchPath + Pattern, faDirectory, Rec) = 0 then
      begin
        try
          repeat
            if ((Rec.Attr and faDirectory) <> 0) and (Rec.Name<>'.') and (Rec.Name<>'..') then begin
              New(DirNode);
              with DirNode^ do begin
                EntryType:=etDirectory;
                Name:=Rec.Name;
                Size:=0;
                Entries := nil;
              end;
              if Level <= edtMaxDirLevel.Value then
                DirNode^.Entries:=FindFiles(SearchPath + Rec.Name, Pattern, Level + 1);
              DirList.Add(DirNode);
              Inc(FTotalCount);
              //WriteLn(DupeString('-', Level) + DirNode^.Name);
            end;
          until (FindNext(Rec) <> 0) or (FTotalCount >= MaxFiles);
        finally
          FindClose(Rec);
        end;
      end;
    end;
    DirList.Sort(@SortFileEntries);
    Result := DirList;
  end;

begin
  btnScan.Enabled:=False;
  pbWorking.Visible := True; Application.ProcessMessages;
  try
    FTotalCount := 0;
    Result := FindFiles(Path, Pattern, 1);
  finally
    pbWorking.Visible:=False;
    btnScan.Enabled:=True;
  end;
end;

end.

