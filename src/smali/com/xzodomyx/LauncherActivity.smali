.class public Lcom/xzodomyx/LauncherActivity;
.super Landroid/app/Activity;
.source "LauncherActivity.java"

# XZO-Domyx PE pre-launch screen.
#
# Built 100% programmatically: no layout XML, no new resources, no R class.
# That is deliberate -- it lets the repack keep the stock resources.arsc and every
# stock resource byte-identical (see docs/00-RECON.md section 5), and it mirrors what
# MainActivity.setupKeyboardViews() already does in this very APK.
#
# Everything that touches storage is wrapped in a catch-all so a failure can never
# stop the game from launching.

.implements Landroid/view/View$OnClickListener;


# static fields
.field public static final PREFS:Ljava/lang/String; = "xzo_domyx_prefs"

.field private static final REQ_SKIN:I = 0x1069


# instance fields
.field private mFps:Landroid/widget/CheckBox;

.field private mLaunchBtn:Landroid/widget/Button;

.field private mSkinBtn:Landroid/widget/Button;

.field private mStatus:Landroid/widget/TextView;

.field private mUser:Landroid/widget/EditText;

.field private mWake:Landroid/widget/CheckBox;


# direct methods
.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Landroid/app/Activity;-><init>()V

    return-void
.end method

.method private prefs()Landroid/content/SharedPreferences;
    .locals 2

    const-string v0, "xzo_domyx_prefs"

    const/4 v1, 0x0

    invoke-virtual {p0, v0, v1}, Lcom/xzodomyx/LauncherActivity;->getSharedPreferences(Ljava/lang/String;I)Landroid/content/SharedPreferences;

    move-result-object v0

    return-object v0
.end method

.method private dp(I)I
    .locals 2

    invoke-virtual {p0}, Lcom/xzodomyx/LauncherActivity;->getResources()Landroid/content/res/Resources;

    move-result-object v0

    invoke-virtual {v0}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;

    move-result-object v0

    iget v0, v0, Landroid/util/DisplayMetrics;->density:F

    int-to-float v1, p1

    mul-float/2addr v0, v1

    float-to-int v0, v0

    return v0
.end method


# virtual methods
.method public onCreate(Landroid/os/Bundle;)V
    .locals 2

    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V

    # forced portrait, per spec
    const/4 v0, 0x1

    invoke-virtual {p0, v0}, Lcom/xzodomyx/LauncherActivity;->setRequestedOrientation(I)V

    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->buildUi()V

    return-void
.end method

.method private rounded(IIII)Landroid/graphics/drawable/GradientDrawable;
    .locals 2

    new-instance v0, Landroid/graphics/drawable/GradientDrawable;

    invoke-direct {v0}, Landroid/graphics/drawable/GradientDrawable;-><init>()V

    invoke-virtual {v0, p1}, Landroid/graphics/drawable/GradientDrawable;->setColor(I)V

    int-to-float v1, p2

    invoke-virtual {v0, v1}, Landroid/graphics/drawable/GradientDrawable;->setCornerRadius(F)V

    if-lez p4, :cond_0

    invoke-virtual {v0, p4, p3}, Landroid/graphics/drawable/GradientDrawable;->setStroke(II)V

    :cond_0
    return-object v0
.end method

.method private styleBtn(Landroid/widget/Button;III)V
    .locals 7

    const/16 v0, 0x8

    invoke-direct {p0, v0}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v0

    new-instance v1, Landroid/graphics/drawable/StateListDrawable;

    invoke-direct {v1}, Landroid/graphics/drawable/StateListDrawable;-><init>()V

    const/4 v2, 0x0

    const/4 v3, 0x1

    new-array v4, v3, [I

    sget v5, Landroid/R$attr;->state_pressed:I

    aput v5, v4, v2

    invoke-direct {p0, p3, v0, v2, v2}, Lcom/xzodomyx/LauncherActivity;->rounded(IIII)Landroid/graphics/drawable/GradientDrawable;

    move-result-object v6

    invoke-virtual {v1, v4, v6}, Landroid/graphics/drawable/StateListDrawable;->addState([ILandroid/graphics/drawable/Drawable;)V

    new-array v4, v2, [I

    invoke-direct {p0, p2, v0, v2, v2}, Lcom/xzodomyx/LauncherActivity;->rounded(IIII)Landroid/graphics/drawable/GradientDrawable;

    move-result-object v6

    invoke-virtual {v1, v4, v6}, Landroid/graphics/drawable/StateListDrawable;->addState([ILandroid/graphics/drawable/Drawable;)V

    invoke-virtual {p1, v1}, Landroid/widget/Button;->setBackgroundDrawable(Landroid/graphics/drawable/Drawable;)V

    invoke-virtual {p1, p4}, Landroid/widget/Button;->setTextColor(I)V

    const/16 v5, 0xe

    invoke-direct {p0, v5}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v5

    invoke-virtual {p1, v5, v5, v5, v5}, Landroid/widget/Button;->setPadding(IIII)V

    return-void
.end method

.method private label(Ljava/lang/String;)Landroid/widget/TextView;
    .locals 3

    new-instance v0, Landroid/widget/TextView;

    invoke-direct {v0, p0}, Landroid/widget/TextView;-><init>(Landroid/content/Context;)V

    invoke-virtual {v0, p1}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V

    const/high16 v1, 0x41200000

    invoke-virtual {v0, v1}, Landroid/widget/TextView;->setTextSize(F)V

    const v1, -0x756458

    invoke-virtual {v0, v1}, Landroid/widget/TextView;->setTextColor(I)V

    const/16 v2, 0x8

    invoke-direct {p0, v2}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v2

    const/4 v1, 0x0

    invoke-virtual {v0, v1, v2, v1, v1}, Landroid/widget/TextView;->setPadding(IIII)V

    return-object v0
.end method

.method private buildUi()V
    .locals 14

    const/16 v0, 0x14

    invoke-direct {p0, v0}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v0

    const/16 v1, 0xa

    invoke-direct {p0, v1}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v1

    # ---------- root column, diagonal gradient ----------
    new-instance v2, Landroid/widget/LinearLayout;

    invoke-direct {v2, p0}, Landroid/widget/LinearLayout;-><init>(Landroid/content/Context;)V

    const/4 v3, 0x1

    invoke-virtual {v2, v3}, Landroid/widget/LinearLayout;->setOrientation(I)V

    invoke-virtual {v2, v3}, Landroid/widget/LinearLayout;->setGravity(I)V

    invoke-virtual {v2, v0, v0, v0, v0}, Landroid/widget/LinearLayout;->setPadding(IIII)V

    new-instance v4, Landroid/graphics/drawable/GradientDrawable;

    sget-object v5, Landroid/graphics/drawable/GradientDrawable$Orientation;->TL_BR:Landroid/graphics/drawable/GradientDrawable$Orientation;

    const/4 v6, 0x2

    new-array v6, v6, [I

    const/4 v7, 0x0

    const v8, -0xf4ede0

    aput v8, v6, v7

    const v8, -0xefd5de

    aput v8, v6, v3

    invoke-direct {v4, v5, v6}, Landroid/graphics/drawable/GradientDrawable;-><init>(Landroid/graphics/drawable/GradientDrawable$Orientation;[I)V

    invoke-virtual {v2, v4}, Landroid/widget/LinearLayout;->setBackgroundDrawable(Landroid/graphics/drawable/Drawable;)V

    # ---------- wordmark, drawn in the GAME'S OWN bitmap font ----------
    new-instance v4, Lcom/xzodomyx/FpsView;

    invoke-direct {v4, p0}, Lcom/xzodomyx/FpsView;-><init>(Landroid/content/Context;)V

    const-string v5, "XZO-DOMYX PE"

    const v6, -0x812cdf

    invoke-virtual {v4, v5, v6}, Lcom/xzodomyx/FpsView;->setLabel(Ljava/lang/String;I)V

    const/4 v5, 0x3

    invoke-direct {p0, v5}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v5

    invoke-virtual {v4, v5}, Lcom/xzodomyx/FpsView;->setPixelScale(I)V

    invoke-virtual {v2, v4}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    # ---------- subtitle ----------
    new-instance v4, Landroid/widget/TextView;

    invoke-direct {v4, p0}, Landroid/widget/TextView;-><init>(Landroid/content/Context;)V

    const-string v5, "Minecraft: Pocket Edition 0.14.3"

    invoke-virtual {v4, v5}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V

    const/high16 v5, 0x41400000

    invoke-virtual {v4, v5}, Landroid/widget/TextView;->setTextSize(F)V

    const v5, -0x756458

    invoke-virtual {v4, v5}, Landroid/widget/TextView;->setTextColor(I)V

    invoke-virtual {v4, v3}, Landroid/widget/TextView;->setGravity(I)V

    invoke-virtual {v4, v7, v1, v7, v0}, Landroid/widget/TextView;->setPadding(IIII)V

    invoke-virtual {v2, v4}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    # ---------- card ----------
    new-instance v7, Landroid/widget/LinearLayout;

    invoke-direct {v7, p0}, Landroid/widget/LinearLayout;-><init>(Landroid/content/Context;)V

    invoke-virtual {v7, v3}, Landroid/widget/LinearLayout;->setOrientation(I)V

    invoke-virtual {v7, v0, v0, v0, v0}, Landroid/widget/LinearLayout;->setPadding(IIII)V

    const v8, -0x19ede5da

    const v9, -0xe0a5bc

    invoke-direct {p0, v3}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v10

    invoke-direct {p0, v8, v1, v9, v10}, Lcom/xzodomyx/LauncherActivity;->rounded(IIII)Landroid/graphics/drawable/GradientDrawable;

    move-result-object v8

    invoke-virtual {v7, v8}, Landroid/widget/LinearLayout;->setBackgroundDrawable(Landroid/graphics/drawable/Drawable;)V

    # username label + field
    const-string v8, "USERNAME"

    invoke-direct {p0, v8}, Lcom/xzodomyx/LauncherActivity;->label(Ljava/lang/String;)Landroid/widget/TextView;

    move-result-object v8

    invoke-virtual {v7, v8}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    new-instance v8, Landroid/widget/EditText;

    invoke-direct {v8, p0}, Landroid/widget/EditText;-><init>(Landroid/content/Context;)V

    invoke-virtual {v8, v3}, Landroid/widget/EditText;->setSingleLine(Z)V

    const-string v9, "Steve"

    invoke-virtual {v8, v9}, Landroid/widget/EditText;->setHint(Ljava/lang/CharSequence;)V

    const v9, -0x756458

    invoke-virtual {v8, v9}, Landroid/widget/EditText;->setHintTextColor(I)V

    const v9, -0x19120d

    invoke-virtual {v8, v9}, Landroid/widget/EditText;->setTextColor(I)V

    const v9, -0xf1e9de

    const v10, -0xd8bfa6

    invoke-direct {p0, v3}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v11

    const/4 v12, 0x6

    invoke-direct {p0, v12}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v12

    invoke-direct {p0, v9, v12, v10, v11}, Lcom/xzodomyx/LauncherActivity;->rounded(IIII)Landroid/graphics/drawable/GradientDrawable;

    move-result-object v9

    invoke-virtual {v8, v9}, Landroid/widget/EditText;->setBackgroundDrawable(Landroid/graphics/drawable/Drawable;)V

    const/16 v9, 0xc

    invoke-direct {p0, v9}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v9

    invoke-virtual {v8, v9, v9, v9, v9}, Landroid/widget/EditText;->setPadding(IIII)V

    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->prefs()Landroid/content/SharedPreferences;

    move-result-object v9

    const-string v10, "username"

    const-string v11, ""

    invoke-interface {v9, v10, v11}, Landroid/content/SharedPreferences;->getString(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;

    move-result-object v9

    invoke-virtual {v8, v9}, Landroid/widget/EditText;->setText(Ljava/lang/CharSequence;)V

    iput-object v8, p0, Lcom/xzodomyx/LauncherActivity;->mUser:Landroid/widget/EditText;

    invoke-virtual {v7, v8}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    # skin section
    const-string v8, "SKIN"

    invoke-direct {p0, v8}, Lcom/xzodomyx/LauncherActivity;->label(Ljava/lang/String;)Landroid/widget/TextView;

    move-result-object v8

    invoke-virtual {v7, v8}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    new-instance v8, Landroid/widget/Button;

    invoke-direct {v8, p0}, Landroid/widget/Button;-><init>(Landroid/content/Context;)V

    const-string v9, "Choose / Upload Skin"

    invoke-virtual {v8, v9}, Landroid/widget/Button;->setText(Ljava/lang/CharSequence;)V

    const v9, -0xe494b6

    const v10, -0xebaec6

    const v11, -0x19120d

    invoke-direct {p0, v8, v9, v10, v11}, Lcom/xzodomyx/LauncherActivity;->styleBtn(Landroid/widget/Button;III)V

    invoke-virtual {v8, p0}, Landroid/widget/Button;->setOnClickListener(Landroid/view/View$OnClickListener;)V

    iput-object v8, p0, Lcom/xzodomyx/LauncherActivity;->mSkinBtn:Landroid/widget/Button;

    invoke-virtual {v7, v8}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    new-instance v8, Landroid/widget/TextView;

    invoke-direct {v8, p0}, Landroid/widget/TextView;-><init>(Landroid/content/Context;)V

    const/high16 v9, 0x41200000

    invoke-virtual {v8, v9}, Landroid/widget/TextView;->setTextSize(F)V

    const v9, -0x756458

    invoke-virtual {v8, v9}, Landroid/widget/TextView;->setTextColor(I)V

    const/4 v9, 0x0

    invoke-direct {p0, v3}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v10

    mul-int/lit8 v10, v10, 0x6

    invoke-virtual {v8, v9, v10, v9, v9}, Landroid/widget/TextView;->setPadding(IIII)V

    iput-object v8, p0, Lcom/xzodomyx/LauncherActivity;->mStatus:Landroid/widget/TextView;

    invoke-virtual {v7, v8}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->refreshSkinStatus()V

    # toggles
    const-string v8, "OPTIONS"

    invoke-direct {p0, v8}, Lcom/xzodomyx/LauncherActivity;->label(Ljava/lang/String;)Landroid/widget/TextView;

    move-result-object v8

    invoke-virtual {v7, v8}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    new-instance v8, Landroid/widget/CheckBox;

    invoke-direct {v8, p0}, Landroid/widget/CheckBox;-><init>(Landroid/content/Context;)V

    const-string v9, "Show FPS counter in game"

    invoke-virtual {v8, v9}, Landroid/widget/CheckBox;->setText(Ljava/lang/CharSequence;)V

    const v9, -0x19120d

    invoke-virtual {v8, v9}, Landroid/widget/CheckBox;->setTextColor(I)V

    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->prefs()Landroid/content/SharedPreferences;

    move-result-object v9

    const-string v10, "fps_counter"

    const/4 v11, 0x0

    invoke-interface {v9, v10, v11}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result v9

    invoke-virtual {v8, v9}, Landroid/widget/CheckBox;->setChecked(Z)V

    iput-object v8, p0, Lcom/xzodomyx/LauncherActivity;->mFps:Landroid/widget/CheckBox;

    invoke-virtual {v7, v8}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    new-instance v8, Landroid/widget/CheckBox;

    invoke-direct {v8, p0}, Landroid/widget/CheckBox;-><init>(Landroid/content/Context;)V

    const-string v9, "Keep screen awake"

    invoke-virtual {v8, v9}, Landroid/widget/CheckBox;->setText(Ljava/lang/CharSequence;)V

    const v9, -0x19120d

    invoke-virtual {v8, v9}, Landroid/widget/CheckBox;->setTextColor(I)V

    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->prefs()Landroid/content/SharedPreferences;

    move-result-object v9

    const-string v10, "keep_awake"

    invoke-interface {v9, v10, v3}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result v9

    invoke-virtual {v8, v9}, Landroid/widget/CheckBox;->setChecked(Z)V

    iput-object v8, p0, Lcom/xzodomyx/LauncherActivity;->mWake:Landroid/widget/CheckBox;

    invoke-virtual {v7, v8}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    invoke-virtual {v2, v7}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;)V

    # ---------- launch ----------
    new-instance v8, Landroid/widget/Button;

    invoke-direct {v8, p0}, Landroid/widget/Button;-><init>(Landroid/content/Context;)V

    const-string v9, "LAUNCH"

    invoke-virtual {v8, v9}, Landroid/widget/Button;->setText(Ljava/lang/CharSequence;)V

    const v9, -0x812cdf

    const v10, -0x944ce4

    const v11, -0xf4ede0

    invoke-direct {p0, v8, v9, v10, v11}, Lcom/xzodomyx/LauncherActivity;->styleBtn(Landroid/widget/Button;III)V

    invoke-virtual {v8, p0}, Landroid/widget/Button;->setOnClickListener(Landroid/view/View$OnClickListener;)V

    iput-object v8, p0, Lcom/xzodomyx/LauncherActivity;->mLaunchBtn:Landroid/widget/Button;

    new-instance v9, Landroid/widget/LinearLayout$LayoutParams;

    const/4 v10, -0x1

    const/4 v11, -0x2

    invoke-direct {v9, v10, v11}, Landroid/widget/LinearLayout$LayoutParams;-><init>(II)V

    const/4 v10, 0x0

    invoke-virtual {v9, v10, v0, v10, v10}, Landroid/widget/LinearLayout$LayoutParams;->setMargins(IIII)V

    invoke-virtual {v2, v8, v9}, Landroid/widget/LinearLayout;->addView(Landroid/view/View;Landroid/view/ViewGroup$LayoutParams;)V

    # ---------- entrance motion (launcher only; no bearing on in-game FPS) ----------
    const/4 v9, 0x0

    int-to-float v9, v9

    invoke-virtual {v7, v9}, Landroid/widget/LinearLayout;->setAlpha(F)V

    const/16 v9, 0x18

    invoke-direct {p0, v9}, Lcom/xzodomyx/LauncherActivity;->dp(I)I

    move-result v9

    int-to-float v9, v9

    invoke-virtual {v7, v9}, Landroid/widget/LinearLayout;->setTranslationY(F)V

    invoke-virtual {v7}, Landroid/widget/LinearLayout;->animate()Landroid/view/ViewPropertyAnimator;

    move-result-object v10

    const/high16 v9, 0x3f800000

    invoke-virtual {v10, v9}, Landroid/view/ViewPropertyAnimator;->alpha(F)Landroid/view/ViewPropertyAnimator;

    move-result-object v10

    const/4 v9, 0x0

    int-to-float v9, v9

    invoke-virtual {v10, v9}, Landroid/view/ViewPropertyAnimator;->translationY(F)Landroid/view/ViewPropertyAnimator;

    move-result-object v10

    const-wide/16 v12, 0x1c2

    invoke-virtual {v10, v12, v13}, Landroid/view/ViewPropertyAnimator;->setDuration(J)Landroid/view/ViewPropertyAnimator;

    move-result-object v10

    invoke-virtual {v10}, Landroid/view/ViewPropertyAnimator;->start()V

    # ---------- scroll host ----------
    new-instance v11, Landroid/widget/ScrollView;

    invoke-direct {v11, p0}, Landroid/widget/ScrollView;-><init>(Landroid/content/Context;)V

    const v9, -0xf4ede0

    invoke-virtual {v11, v9}, Landroid/widget/ScrollView;->setBackgroundColor(I)V

    invoke-virtual {v11, v2}, Landroid/widget/ScrollView;->addView(Landroid/view/View;)V

    invoke-virtual {p0, v11}, Lcom/xzodomyx/LauncherActivity;->setContentView(Landroid/view/View;)V

    return-void
.end method

.method private refreshSkinStatus()V
    .locals 4

    iget-object v0, p0, Lcom/xzodomyx/LauncherActivity;->mStatus:Landroid/widget/TextView;

    if-eqz v0, :cond_done

    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->prefs()Landroid/content/SharedPreferences;

    move-result-object v1

    const-string v2, "skin_path"

    const-string v3, ""

    invoke-interface {v1, v2, v3}, Landroid/content/SharedPreferences;->getString(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;

    move-result-object v1

    invoke-virtual {v1}, Ljava/lang/String;->length()I

    move-result v2

    if-eqz v2, :cond_have

    const-string v2, "No skin selected. The game\'s Skins screen will list any skin you pick here."

    invoke-virtual {v0, v2}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V

    goto :goto_done

    :cond_have
    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    const-string v3, "Skin staged: "

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v2

    invoke-virtual {v0, v2}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V

    :goto_done
    :cond_done
    return-void
.end method

.method public onClick(Landroid/view/View;)V
    .locals 1

    iget-object v0, p0, Lcom/xzodomyx/LauncherActivity;->mSkinBtn:Landroid/widget/Button;

    if-ne p1, v0, :cond_launch

    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->pickSkin()V

    return-void

    :cond_launch
    iget-object v0, p0, Lcom/xzodomyx/LauncherActivity;->mLaunchBtn:Landroid/widget/Button;

    if-ne p1, v0, :cond_none

    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->doLaunch()V

    :cond_none
    return-void
.end method

.method private pickSkin()V
    .locals 4

    :try_start_0
    new-instance v0, Landroid/content/Intent;

    const-string v1, "android.intent.action.GET_CONTENT"

    invoke-direct {v0, v1}, Landroid/content/Intent;-><init>(Ljava/lang/String;)V

    const-string v1, "image/*"

    invoke-virtual {v0, v1}, Landroid/content/Intent;->setType(Ljava/lang/String;)Landroid/content/Intent;

    const-string v1, "android.intent.category.OPENABLE"

    invoke-virtual {v0, v1}, Landroid/content/Intent;->addCategory(Ljava/lang/String;)Landroid/content/Intent;

    const-string v1, "Select a skin PNG"

    invoke-static {v0, v1}, Landroid/content/Intent;->createChooser(Landroid/content/Intent;Ljava/lang/CharSequence;)Landroid/content/Intent;

    move-result-object v1

    const/16 v2, 0x1069

    invoke-virtual {p0, v1, v2}, Lcom/xzodomyx/LauncherActivity;->startActivityForResult(Landroid/content/Intent;I)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    iget-object v1, p0, Lcom/xzodomyx/LauncherActivity;->mStatus:Landroid/widget/TextView;

    if-eqz v1, :cond_0

    const-string v2, "No image picker available on this device."

    invoke-virtual {v1, v2}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V

    :cond_0
    return-void
.end method

.method protected onActivityResult(IILandroid/content/Intent;)V
    .locals 12

    invoke-super {p0, p1, p2, p3}, Landroid/app/Activity;->onActivityResult(IILandroid/content/Intent;)V

    const/16 v0, 0x1069

    if-eq p1, v0, :cond_ours

    return-void

    :cond_ours
    const/4 v0, -0x1

    if-eq p2, v0, :cond_ok

    return-void

    :cond_ok
    if-nez p3, :cond_have_data

    return-void

    :cond_have_data
    invoke-virtual {p3}, Landroid/content/Intent;->getData()Landroid/net/Uri;

    move-result-object v1

    if-nez v1, :cond_have_uri

    return-void

    :cond_have_uri
    :try_start_0
    # 1) read just the bounds so we can sanity-check the skin geometry
    new-instance v2, Landroid/graphics/BitmapFactory$Options;

    invoke-direct {v2}, Landroid/graphics/BitmapFactory$Options;-><init>()V

    const/4 v3, 0x1

    iput-boolean v3, v2, Landroid/graphics/BitmapFactory$Options;->inJustDecodeBounds:Z

    invoke-virtual {p0}, Lcom/xzodomyx/LauncherActivity;->getContentResolver()Landroid/content/ContentResolver;

    move-result-object v3

    invoke-virtual {v3, v1}, Landroid/content/ContentResolver;->openInputStream(Landroid/net/Uri;)Ljava/io/InputStream;

    move-result-object v3

    const/4 v4, 0x0

    invoke-static {v3, v4, v2}, Landroid/graphics/BitmapFactory;->decodeStream(Ljava/io/InputStream;Landroid/graphics/Rect;Landroid/graphics/BitmapFactory$Options;)Landroid/graphics/Bitmap;

    invoke-virtual {v3}, Ljava/io/InputStream;->close()V

    iget v5, v2, Landroid/graphics/BitmapFactory$Options;->outWidth:I

    iget v6, v2, Landroid/graphics/BitmapFactory$Options;->outHeight:I

    # 2) copy into a MediaStore-visible folder. The game's own skin picker is an
    # ACTION_PICK over MediaStore images, so anything we drop here shows up in it.
    const-string v7, "Pictures"

    invoke-static {v7}, Landroid/os/Environment;->getExternalStoragePublicDirectory(Ljava/lang/String;)Ljava/io/File;

    move-result-object v7

    new-instance v8, Ljava/io/File;

    const-string v9, "XZO-Domyx"

    invoke-direct {v8, v7, v9}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V

    invoke-virtual {v8}, Ljava/io/File;->mkdirs()Z

    new-instance v9, Ljava/io/File;

    const-string v10, "xzo_skin.png"

    invoke-direct {v9, v8, v10}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V

    invoke-virtual {p0}, Lcom/xzodomyx/LauncherActivity;->getContentResolver()Landroid/content/ContentResolver;

    move-result-object v10

    invoke-virtual {v10, v1}, Landroid/content/ContentResolver;->openInputStream(Landroid/net/Uri;)Ljava/io/InputStream;

    move-result-object v10

    invoke-static {v10, v9}, Lcom/xzodomyx/LauncherActivity;->copyStream(Ljava/io/InputStream;Ljava/io/File;)V

    # 3) make it visible to the MediaStore immediately
    invoke-virtual {v9}, Ljava/io/File;->getAbsolutePath()Ljava/lang/String;

    move-result-object v10

    const/4 v11, 0x1

    new-array v11, v11, [Ljava/lang/String;

    const/4 v0, 0x0

    aput-object v10, v11, v0

    const/4 v0, 0x0

    invoke-static {p0, v11, v0, v0}, Landroid/media/MediaScannerConnection;->scanFile(Landroid/content/Context;[Ljava/lang/String;[Ljava/lang/String;Landroid/media/MediaScannerConnection$OnScanCompletedListener;)V

    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->prefs()Landroid/content/SharedPreferences;

    move-result-object v0

    invoke-interface {v0}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object v0

    const-string v4, "skin_path"

    invoke-interface {v0, v4, v10}, Landroid/content/SharedPreferences$Editor;->putString(Ljava/lang/String;Ljava/lang/String;)Landroid/content/SharedPreferences$Editor;

    move-result-object v0

    invoke-interface {v0}, Landroid/content/SharedPreferences$Editor;->apply()V

    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->refreshSkinStatus()V

    # 4) warn (but do not block) if it is not a Minecraft skin sheet
    const/16 v0, 0x40

    if-ne v5, v0, :cond_warn

    const/16 v0, 0x20

    if-eq v6, v0, :cond_good

    const/16 v0, 0x40

    if-eq v6, v0, :cond_good

    :cond_warn
    iget-object v0, p0, Lcom/xzodomyx/LauncherActivity;->mStatus:Landroid/widget/TextView;

    if-eqz v0, :cond_good

    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V

    const-string v7, "Warning: image is "

    invoke-virtual {v4, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    const-string v7, "x"

    invoke-virtual {v4, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    const-string v7, ", not 64x32 or 64x64. Saved anyway."

    invoke-virtual {v4, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v4

    invoke-virtual {v0, v4}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V

    :cond_good
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    iget-object v1, p0, Lcom/xzodomyx/LauncherActivity;->mStatus:Landroid/widget/TextView;

    if-eqz v1, :cond_end

    const-string v2, "Could not read that image."

    invoke-virtual {v1, v2}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V

    :cond_end
    return-void
.end method

.method private static copyStream(Ljava/io/InputStream;Ljava/io/File;)V
    .locals 4

    new-instance v0, Ljava/io/FileOutputStream;

    invoke-direct {v0, p1}, Ljava/io/FileOutputStream;-><init>(Ljava/io/File;)V

    const/16 v1, 0x2000

    new-array v1, v1, [B

    :goto_0
    invoke-virtual {p0, v1}, Ljava/io/InputStream;->read([B)I

    move-result v2

    const/4 v3, 0x0

    if-lez v2, :cond_0

    invoke-virtual {v0, v1, v3, v2}, Ljava/io/FileOutputStream;->write([BII)V

    goto :goto_0

    :cond_0
    invoke-virtual {v0}, Ljava/io/FileOutputStream;->flush()V

    invoke-virtual {v0}, Ljava/io/FileOutputStream;->close()V

    invoke-virtual {p0}, Ljava/io/InputStream;->close()V

    return-void
.end method

.method private doLaunch()V
    .locals 6

    # persist our own settings (our SharedPreferences, never the game's)
    :try_start_0
    iget-object v0, p0, Lcom/xzodomyx/LauncherActivity;->mUser:Landroid/widget/EditText;

    invoke-virtual {v0}, Landroid/widget/EditText;->getText()Landroid/text/Editable;

    move-result-object v0

    invoke-interface {v0}, Landroid/text/Editable;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lcom/xzodomyx/LauncherActivity;->sanitize(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v0

    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->prefs()Landroid/content/SharedPreferences;

    move-result-object v1

    invoke-interface {v1}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object v1

    const-string v2, "username"

    invoke-interface {v1, v2, v0}, Landroid/content/SharedPreferences$Editor;->putString(Ljava/lang/String;Ljava/lang/String;)Landroid/content/SharedPreferences$Editor;

    move-result-object v1

    const-string v2, "fps_counter"

    iget-object v3, p0, Lcom/xzodomyx/LauncherActivity;->mFps:Landroid/widget/CheckBox;

    invoke-virtual {v3}, Landroid/widget/CheckBox;->isChecked()Z

    move-result v3

    invoke-interface {v1, v2, v3}, Landroid/content/SharedPreferences$Editor;->putBoolean(Ljava/lang/String;Z)Landroid/content/SharedPreferences$Editor;

    move-result-object v1

    const-string v2, "keep_awake"

    iget-object v3, p0, Lcom/xzodomyx/LauncherActivity;->mWake:Landroid/widget/CheckBox;

    invoke-virtual {v3}, Landroid/widget/CheckBox;->isChecked()Z

    move-result v3

    invoke-interface {v1, v2, v3}, Landroid/content/SharedPreferences$Editor;->putBoolean(Ljava/lang/String;Z)Landroid/content/SharedPreferences$Editor;

    move-result-object v1

    invoke-interface {v1}, Landroid/content/SharedPreferences$Editor;->apply()V

    # push the username through the game's OWN storage: options.txt key mp_username
    # (key confirmed in libminecraftpe.so .rodata -- see docs/00-RECON.md 3a)
    invoke-virtual {v0}, Ljava/lang/String;->length()I

    move-result v2

    if-eqz v2, :cond_skip

    const-string v2, "mp_username"

    invoke-static {v2, v0}, Lcom/xzodomyx/LauncherActivity;->writeGameOption(Ljava/lang/String;Ljava/lang/String;)V

    :cond_skip
    # One-time note. Per confirmed finding B a launcher cannot apply a custom skin
    # end-to-end on 0.14.3, so tell the user plainly that the last step is in-game.
    invoke-direct {p0}, Lcom/xzodomyx/LauncherActivity;->prefs()Landroid/content/SharedPreferences;

    move-result-object v2

    const-string v3, "skin_path"

    const-string v4, ""

    invoke-interface {v2, v3, v4}, Landroid/content/SharedPreferences;->getString(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;

    move-result-object v3

    invoke-virtual {v3}, Ljava/lang/String;->length()I

    move-result v3

    if-eqz v3, :cond_nonote

    const-string v3, "skin_note_shown"

    const/4 v4, 0x0

    invoke-interface {v2, v3, v4}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result v3

    if-nez v3, :cond_nonote

    const-string v3, "Skin prepared - open Settings > Skin in-game once to select it from your gallery."

    const/4 v4, 0x1

    invoke-static {p0, v3, v4}, Landroid/widget/Toast;->makeText(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;

    move-result-object v3

    invoke-virtual {v3}, Landroid/widget/Toast;->show()V

    invoke-interface {v2}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object v2

    const-string v3, "skin_note_shown"

    const/4 v4, 0x1

    invoke-interface {v2, v3, v4}, Landroid/content/SharedPreferences$Editor;->putBoolean(Ljava/lang/String;Z)Landroid/content/SharedPreferences$Editor;

    move-result-object v2

    invoke-interface {v2}, Landroid/content/SharedPreferences$Editor;->apply()V

    :cond_nonote
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    goto :goto_go

    :catch_0
    move-exception v1

    # never block the game from starting
    :goto_go
    :try_start_1
    # hand off in landscape so there is no portrait->landscape flash on the way in.
    # MainActivity itself stays on its stock android:screenOrientation="sensorLandscape".
    const/4 v5, 0x0

    invoke-virtual {p0, v5}, Lcom/xzodomyx/LauncherActivity;->setRequestedOrientation(I)V

    new-instance v3, Landroid/content/Intent;

    const-class v4, Lcom/mojang/minecraftpe/MainActivity;

    invoke-direct {v3, p0, v4}, Landroid/content/Intent;-><init>(Landroid/content/Context;Ljava/lang/Class;)V

    invoke-virtual {p0, v3}, Lcom/xzodomyx/LauncherActivity;->startActivity(Landroid/content/Intent;)V
    :try_end_1
    .catch Ljava/lang/Throwable; {:try_start_1 .. :try_end_1} :catch_1

    :catch_1
    invoke-virtual {p0}, Lcom/xzodomyx/LauncherActivity;->finish()V

    return-void
.end method

.method private static sanitize(Ljava/lang/String;)Ljava/lang/String;
    .locals 5

    if-eqz p0, :cond_null

    invoke-virtual {p0}, Ljava/lang/String;->trim()Ljava/lang/String;

    move-result-object v0

    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const/4 v2, 0x0

    :goto_0
    invoke-virtual {v0}, Ljava/lang/String;->length()I

    move-result v3

    if-ge v2, v3, :cond_end

    invoke-virtual {v0, v2}, Ljava/lang/String;->charAt(I)C

    move-result v3

    # drop control chars, ':' and newlines -- they would corrupt options.txt
    const/16 v4, 0x20

    if-lt v3, v4, :cond_next

    const/16 v4, 0x3a

    if-eq v3, v4, :cond_next

    invoke-virtual {v1, v3}, Ljava/lang/StringBuilder;->append(C)Ljava/lang/StringBuilder;

    :cond_next
    add-int/lit8 v2, v2, 0x1

    goto :goto_0

    :cond_end
    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v1

    return-object v1

    :cond_null
    const-string v0, ""

    return-object v0
.end method

.method private static writeGameOption(Ljava/lang/String;Ljava/lang/String;)V
    .locals 9

    # <external>/games/com.mojang/minecraftpe/options.txt -- path strings confirmed in
    # libminecraftpe.so: "/games/com.mojang/", "/minecraftpe", "/options.txt"
    invoke-static {}, Landroid/os/Environment;->getExternalStorageDirectory()Ljava/io/File;

    move-result-object v0

    new-instance v1, Ljava/io/File;

    const-string v2, "games/com.mojang/minecraftpe"

    invoke-direct {v1, v0, v2}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V

    invoke-virtual {v1}, Ljava/io/File;->mkdirs()Z

    new-instance v2, Ljava/io/File;

    const-string v3, "options.txt"

    invoke-direct {v2, v1, v3}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V

    new-instance v3, Ljava/lang/StringBuilder;

    invoke-direct {v3}, Ljava/lang/StringBuilder;-><init>()V

    const/4 v4, 0x0

    invoke-virtual {v2}, Ljava/io/File;->exists()Z

    move-result v5

    if-eqz v5, :cond_write

    new-instance v5, Ljava/io/BufferedReader;

    new-instance v6, Ljava/io/FileReader;

    invoke-direct {v6, v2}, Ljava/io/FileReader;-><init>(Ljava/io/File;)V

    invoke-direct {v5, v6}, Ljava/io/BufferedReader;-><init>(Ljava/io/Reader;)V

    :goto_0
    invoke-virtual {v5}, Ljava/io/BufferedReader;->readLine()Ljava/lang/String;

    move-result-object v6

    if-eqz v6, :cond_eof

    new-instance v7, Ljava/lang/StringBuilder;

    invoke-direct {v7}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v7, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v8, ":"

    invoke-virtual {v7, v8}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v7}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v7

    invoke-virtual {v6, v7}, Ljava/lang/String;->startsWith(Ljava/lang/String;)Z

    move-result v7

    if-eqz v7, :cond_keep

    # replace the existing value in place
    invoke-static {p0, p1}, Lcom/xzodomyx/LauncherActivity;->kv(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;

    move-result-object v6

    const/4 v4, 0x1

    :cond_keep
    invoke-virtual {v3, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v6, "\n"

    invoke-virtual {v3, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    goto :goto_0

    :cond_eof
    invoke-virtual {v5}, Ljava/io/BufferedReader;->close()V

    :cond_write
    if-nez v4, :cond_have

    invoke-static {p0, p1}, Lcom/xzodomyx/LauncherActivity;->kv(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;

    move-result-object v5

    invoke-virtual {v3, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v5, "\n"

    invoke-virtual {v3, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    :cond_have
    new-instance v5, Ljava/io/FileOutputStream;

    invoke-direct {v5, v2}, Ljava/io/FileOutputStream;-><init>(Ljava/io/File;)V

    invoke-virtual {v3}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v6

    invoke-virtual {v6}, Ljava/lang/String;->getBytes()[B

    move-result-object v6

    invoke-virtual {v5, v6}, Ljava/io/FileOutputStream;->write([B)V

    invoke-virtual {v5}, Ljava/io/FileOutputStream;->flush()V

    invoke-virtual {v5}, Ljava/io/FileOutputStream;->close()V

    return-void
.end method

.method private static kv(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
    .locals 2

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v1, ":"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    return-object v0
.end method
