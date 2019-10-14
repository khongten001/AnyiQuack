unit Main;

interface

uses
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Math,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,

  AnyiQuack,
  AQPControlAnimations; // AnyiQuack-Plugin

type
  TMainForm = class(TForm)
    AddPanelButton: TButton;
    PanelSizeTrackBar: TTrackBar;
    RemovePanelButton: TButton;
    Label1: TLabel;
    DisturbedComboBox: TComboBox;
    Label2: TLabel;
    Label3: TLabel;
    TopPanel: TPanel;
    BottomPanel: TPanel;
    Label5: TLabel;
    AnimationDurationTrackBar: TTrackBar;
    HoverColorBox: TColorBox;
    Label6: TLabel;
    HoverShakeCheckBox: TCheckBox;
    procedure AddPanelButtonClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure PanelSizeTrackBarChange(Sender: TObject);
    procedure RemovePanelButtonClick(Sender: TObject);

  private
    class var
    BoundsAnimationID: Integer;
    HoverAnimationID: Integer;
    HoverShakeAnimationID: Integer;

  private
    FPanelCounter: Integer;
  public
    class constructor Create;

    procedure PanelMouseEnter(Sender: TObject);
    procedure PanelMouseLeave(Sender: TObject);
    procedure PanelHoverHandler(Sender: TObject; MouseOver: Boolean);

    procedure UpdateAlign;

    function GetPanelsAQ: TAQ;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

const
  ActivePanelTag = 69;
  InactivePanelTag = 70;

class constructor TMainForm.Create;
begin
  BoundsAnimationID := TAQ.GetUniqueID;
  HoverAnimationID := TAQ.GetUniqueID;
  HoverShakeAnimationID := TAQ.GetUniqueID;
end;

procedure TMainForm.AddPanelButtonClick(Sender: TObject);
var
  P: TPanel;
begin
  Inc(FPanelCounter);
  P := TPanel.Create(Self);
  P.Parent := Self;
  P.SetBounds(-100, -100, 10, 10);
  P.ParentBackground := FALSE;
  P.Color := clBtnFace;
  P.Caption := Format('Panel #%d', [FPanelCounter]);
  P.OnMouseEnter := PanelMouseEnter;
  P.OnMouseLeave := PanelMouseLeave;
  P.DoubleBuffered := True;
  P.BringToFront;
  P.Tag := ActivePanelTag;
  TopPanel.BringToFront;
  BottomPanel.BringToFront;
  UpdateAlign;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  UpdateAlign;
end;

function TMainForm.GetPanelsAQ: TAQ;
begin
  Result:=Take(MainForm)
    .ChildrenChain
    .FilterChain(
      function(AQ: TAQ; O: TObject): Boolean
      begin
        Result := (O is TPanel) and (TControl(O).Tag = ActivePanelTag);
      end);
end;

procedure TMainForm.PanelSizeTrackBarChange(Sender: TObject);
begin
  UpdateAlign;
end;

procedure TMainForm.RemovePanelButtonClick(Sender: TObject);
begin
  GetPanelsAQ
    .SliceChain(-1) // Reduce to the last panel
    .Each(
      function(AQ: TAQ; O: TObject): Boolean
      begin
        Result := TRUE;
        Dec(FPanelCounter);
        TControl(O).Tag := InactivePanelTag; // This excludes the panel from being taken by GetPanelsAQ
        AQ
          .CancelAnimations
          .Plugin<TAQPControlAnimations>
          .BoundsAnimation(TControl(O).Left, Height, -1, -1,
            AnimationDurationTrackBar.Position, 0, TAQ.Ease(etQuad),
            procedure(Sender: TObject)
            begin
              Sender.Free;
            end);
      end);
  UpdateAlign;
end;

procedure TMainForm.PanelHoverHandler(Sender: TObject; MouseOver: Boolean);
var
  AQ: TAQ;
  AQAniPlugin: TAQPControlAnimations;
  ShakeIt: Boolean;
begin
  AQ := Take(Sender);

  if MouseOver then
  begin
    ShakeIt := HoverShakeCheckBox.Checked and
      not TAQ.HasActiveActors([arAnimation], Sender, BoundsAnimationID);

    AQAniPlugin := AQ
      .CancelAnimations(HoverAnimationID)
      .Plugin<TAQPControlAnimations>;
    AQAniPlugin.FontColorAnimation(ColorToRGB(HoverColorBox.Selected) xor $FFFFFF, 600,
      HoverAnimationID, TAQ.Ease(etCubic));
    AQAniPlugin.BackgroundColorAnimation(HoverColorBox.Selected, 300, HoverAnimationID,
      TAQ.Ease(etSinus));

    if ShakeIt then
      AQAniPlugin.ShakeAnimation(3, Floor(PanelSizeTrackBar.Position * 0.1), 2,
        Floor(PanelSizeTrackBar.Position * 0.05), 1000 + AnimationDurationTrackBar.Position,
        BoundsAnimationID);
  end
  else
  begin
    AQAniPlugin := AQ.FinishAnimations(HoverAnimationID).Plugin<TAQPControlAnimations>;
    AQAniPlugin.FontColorAnimation(clWindowText, 750, HoverAnimationID,
      TAQ.Ease(etCubic));
    AQAniPlugin.BackgroundColorAnimation(clBtnFace, 1500, HoverAnimationID, TAQ.Ease(etSinus));
  end;
end;

procedure TMainForm.PanelMouseEnter(Sender: TObject);
begin
  PanelHoverHandler(Sender, TRUE);
end;

procedure TMainForm.PanelMouseLeave(Sender: TObject);
begin
  PanelHoverHandler(Sender, FALSE);
end;

procedure TMainForm.UpdateAlign;
var
  PanelsAQ: TAQ;
  AHeight, AWidth: Integer;
  PQSize, PIndex: Integer;
  PColumns, PRows, LeftOffset, TopOffset: Word;
begin
  PanelsAQ := GetPanelsAQ;

  RemovePanelButton.Enabled := PanelsAQ.Count > 0;

  AWidth := ClientWidth;
  AHeight := ClientHeight - TopPanel.Height - BottomPanel.Height;
  PQSize := PanelSizeTrackBar.Position;
  DivMod(AWidth, PQSize, PColumns, LeftOffset);
  DivMod(AHeight, PQSize, PRows, TopOffset);
  PColumns := Max(PColumns, 1);
  LeftOffset := (AWidth - (Min(PColumns, PanelsAQ.Count) * PQSize)) div 2;
  TopOffset := ((AHeight - (Min(Ceil(PanelsAQ.Count / PColumns), PRows) * PQSize)) div 2) +
    TopPanel.Height;
  PIndex := 0;

  PanelsAQ
    .CancelDelays(BoundsAnimationID)
    .EachDelay(50,
      function(AQ: TAQ; O: TObject): Boolean
      var
        TargetLeft, TargetTop: Integer;
        XTile, YTile, Dummy: Word;
      begin
        Result := True;

        // Finish or cancel the running animations
        if PIndex = 0 then
        begin
          if DisturbedComboBox.ItemIndex = 0 then
            AQ.CancelAnimations(BoundsAnimationID)
          else
            AQ.FinishAnimations(BoundsAnimationID);
        end;

        YTile := Floor(PIndex/PColumns);
        DivMod(((PIndex - (YTile * PColumns)) + PColumns), PColumns, Dummy, XTile);

        TargetLeft := (XTile * PQSize) + LeftOffset;
        TargetTop := (YTile * PQSize) + TopOffset;

        Take(O)
          .Plugin<TAQPControlAnimations>
          .BoundsAnimation(TargetLeft, TargetTop, PQSize, PQSize,
            AnimationDurationTrackBar.Position, BoundsAnimationID, TAQ.Ease(etElastic));
        Inc(PIndex);
      end, BoundsAnimationID)
    .Die;
end;

end.
