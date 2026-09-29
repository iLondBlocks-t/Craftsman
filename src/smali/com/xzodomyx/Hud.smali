.class public Lcom/xzodomyx/Hud;
.super Ljava/lang/Object;
.source "Hud.java"

# Feature 2 -- always-on FPS counter for the XZO-Domyx PE build.
#
# Attached from MainActivity.onResume, detached from MainActivity.onPause.
#
# Overlay mechanism: PopupWindow, i.e. the *same* mechanism the stock game already uses
# in MainActivity.setupKeyboardViews(), which is the only overlay approach proven to work
# against this NativeActivity (confirmed finding A). It is created with
# setTouchable(false)/setFocusable(false), so it adds FLAG_NOT_TOUCHABLE and cannot steal
# a single touch event from the game.
#
# A plain decor-view TextView was NOT chosen: verifying that empirically needs a device or
# emulator, and neither exists in this build environment. Rather than ship an unverified
# guess, this uses the mechanism already proven in this exact binary. See docs.
#
# Every entry point is wrapped in a catch-all: a HUD must never be able to crash the game.

.implements Landroid/view/Choreographer$FrameCallback;
.implements Ljava/lang/Runnable;


# static fields
.field static sAnchor:Landroid/view/View;

.field static sFrames:I

.field static sLast:J

.field static sMargin:I

.field static sPopup:Landroid/widget/PopupWindow;

.field static sSelf:Lcom/xzodomyx/Hud;

.field static sText:Lcom/xzodomyx/FpsView;


# direct methods
.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method

.method public static attach(Landroid/app/Activity;)V
    .locals 8

    :try_start_0
    sget-object v0, Lcom/xzodomyx/Hud;->sPopup:Landroid/widget/PopupWindow;

    if-nez v0, :cond_out

    const-string v0, "xzo_domyx_prefs"

    const/4 v1, 0x0

    invoke-virtual {p0, v0, v1}, Landroid/app/Activity;->getSharedPreferences(Ljava/lang/String;I)Landroid/content/SharedPreferences;

    move-result-object v0

    # "Keep screen awake" toggle from the splash screen. Opt-in only, so stock
    # behaviour is untouched unless the user ticks it.
    const-string v1, "keep_awake"

    const/4 v2, 0x1

    invoke-interface {v0, v1, v2}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result v1

    if-eqz v1, :cond_nowake

    invoke-virtual {p0}, Landroid/app/Activity;->getWindow()Landroid/view/Window;

    move-result-object v1

    const/16 v2, 0x80

    invoke-virtual {v1, v2}, Landroid/view/Window;->addFlags(I)V

    :cond_nowake
    const-string v1, "fps_counter"

    const/4 v2, 0x0

    invoke-interface {v0, v1, v2}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result v1

    if-eqz v1, :cond_out

    # safe-area margin, scaled for density
    invoke-virtual {p0}, Landroid/app/Activity;->getResources()Landroid/content/res/Resources;

    move-result-object v1

    invoke-virtual {v1}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;

    move-result-object v1

    iget v1, v1, Landroid/util/DisplayMetrics;->density:F

    const/high16 v2, 0x41000000    # 8.0f

    mul-float/2addr v1, v2

    float-to-int v1, v1

    sput v1, Lcom/xzodomyx/Hud;->sMargin:I

    # Feature C: the game's own bitmap font, no background plate
    new-instance v2, Lcom/xzodomyx/FpsView;

    invoke-direct {v2, p0}, Lcom/xzodomyx/FpsView;-><init>(Landroid/content/Context;)V

    new-instance v3, Landroid/widget/PopupWindow;

    const/4 v4, -0x2               # WRAP_CONTENT

    invoke-direct {v3, v2, v4, v4}, Landroid/widget/PopupWindow;-><init>(Landroid/view/View;II)V

    const/4 v4, 0x0

    # display-only: FLAG_NOT_TOUCHABLE, never intercepts game input
    invoke-virtual {v3, v4}, Landroid/widget/PopupWindow;->setTouchable(Z)V

    invoke-virtual {v3, v4}, Landroid/widget/PopupWindow;->setFocusable(Z)V

    invoke-virtual {v3, v4}, Landroid/widget/PopupWindow;->setOutsideTouchable(Z)V

    invoke-virtual {v3, v4}, Landroid/widget/PopupWindow;->setClippingEnabled(Z)V

    sput-object v3, Lcom/xzodomyx/Hud;->sPopup:Landroid/widget/PopupWindow;

    sput-object v2, Lcom/xzodomyx/Hud;->sText:Lcom/xzodomyx/FpsView;

    const/4 v5, 0x0

    sput v5, Lcom/xzodomyx/Hud;->sFrames:I

    const-wide/16 v6, 0x0

    sput-wide v6, Lcom/xzodomyx/Hud;->sLast:J

    new-instance v5, Lcom/xzodomyx/Hud;

    invoke-direct {v5}, Lcom/xzodomyx/Hud;-><init>()V

    sput-object v5, Lcom/xzodomyx/Hud;->sSelf:Lcom/xzodomyx/Hud;

    invoke-virtual {p0}, Landroid/app/Activity;->getWindow()Landroid/view/Window;

    move-result-object v6

    invoke-virtual {v6}, Landroid/view/Window;->getDecorView()Landroid/view/View;

    move-result-object v6

    sput-object v6, Lcom/xzodomyx/Hud;->sAnchor:Landroid/view/View;

    # defer showing: onResume does not guarantee the decor view has a window token yet
    invoke-virtual {v6, v5}, Landroid/view/View;->post(Ljava/lang/Runnable;)Z

    :cond_out
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method

.method public static detach()V
    .locals 4

    :try_start_0
    sget-object v0, Lcom/xzodomyx/Hud;->sSelf:Lcom/xzodomyx/Hud;

    if-eqz v0, :cond_a

    invoke-static {}, Landroid/view/Choreographer;->getInstance()Landroid/view/Choreographer;

    move-result-object v1

    invoke-virtual {v1, v0}, Landroid/view/Choreographer;->removeFrameCallback(Landroid/view/Choreographer$FrameCallback;)V

    :cond_a
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :goto_0
    :try_start_1
    sget-object v0, Lcom/xzodomyx/Hud;->sPopup:Landroid/widget/PopupWindow;

    if-eqz v0, :cond_b

    invoke-virtual {v0}, Landroid/widget/PopupWindow;->dismiss()V

    :cond_b
    :try_end_1
    .catch Ljava/lang/Throwable; {:try_start_1 .. :try_end_1} :catch_1

    :goto_1
    const/4 v0, 0x0

    sput-object v0, Lcom/xzodomyx/Hud;->sPopup:Landroid/widget/PopupWindow;

    sput-object v0, Lcom/xzodomyx/Hud;->sText:Lcom/xzodomyx/FpsView;

    sput-object v0, Lcom/xzodomyx/Hud;->sSelf:Lcom/xzodomyx/Hud;

    sput-object v0, Lcom/xzodomyx/Hud;->sAnchor:Landroid/view/View;

    const/4 v1, 0x0

    sput v1, Lcom/xzodomyx/Hud;->sFrames:I

    const-wide/16 v2, 0x0

    sput-wide v2, Lcom/xzodomyx/Hud;->sLast:J

    return-void

    :catch_0
    move-exception v0

    goto :goto_0

    :catch_1
    move-exception v0

    goto :goto_1
.end method


# virtual methods
.method public run()V
    .locals 4

    :try_start_0
    sget-object v0, Lcom/xzodomyx/Hud;->sPopup:Landroid/widget/PopupWindow;

    if-eqz v0, :cond_out

    sget-object v1, Lcom/xzodomyx/Hud;->sAnchor:Landroid/view/View;

    if-eqz v1, :cond_out

    const/16 v2, 0x33              # Gravity.TOP | Gravity.LEFT

    sget v3, Lcom/xzodomyx/Hud;->sMargin:I

    invoke-virtual {v0, v1, v2, v3, v3}, Landroid/widget/PopupWindow;->showAtLocation(Landroid/view/View;III)V

    invoke-static {}, Landroid/view/Choreographer;->getInstance()Landroid/view/Choreographer;

    move-result-object v0

    invoke-virtual {v0, p0}, Landroid/view/Choreographer;->postFrameCallback(Landroid/view/Choreographer$FrameCallback;)V

    :cond_out
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method

.method public doFrame(J)V
    .locals 10

    :try_start_0
    sget-object v0, Lcom/xzodomyx/Hud;->sPopup:Landroid/widget/PopupWindow;

    if-eqz v0, :cond_out

    sget v0, Lcom/xzodomyx/Hud;->sFrames:I

    add-int/lit8 v0, v0, 0x1

    sput v0, Lcom/xzodomyx/Hud;->sFrames:I

    sget-wide v2, Lcom/xzodomyx/Hud;->sLast:J

    const-wide/16 v4, 0x0

    cmp-long v1, v2, v4

    if-nez v1, :cond_have

    # first frame of the window
    sput-wide p1, Lcom/xzodomyx/Hud;->sLast:J

    goto :goto_post

    :cond_have
    sub-long v4, p1, v2

    const-wide v6, 0x3b9aca00      # 1 second in nanoseconds

    cmp-long v1, v4, v6

    if-ltz v1, :goto_post

    # rolling 1-second window: fps = frames * 1e9 / elapsed
    sget v0, Lcom/xzodomyx/Hud;->sFrames:I

    int-to-long v8, v0

    mul-long/2addr v8, v6

    div-long/2addr v8, v4

    long-to-int v0, v8

    sget-object v1, Lcom/xzodomyx/Hud;->sText:Lcom/xzodomyx/FpsView;

    if-eqz v1, :cond_reset

    invoke-virtual {v1, v0}, Lcom/xzodomyx/FpsView;->setFps(I)V

    :cond_reset
    const/4 v0, 0x0

    sput v0, Lcom/xzodomyx/Hud;->sFrames:I

    sput-wide p1, Lcom/xzodomyx/Hud;->sLast:J

    :goto_post
    invoke-static {}, Landroid/view/Choreographer;->getInstance()Landroid/view/Choreographer;

    move-result-object v0

    invoke-virtual {v0, p0}, Landroid/view/Choreographer;->postFrameCallback(Landroid/view/Choreographer$FrameCallback;)V

    :cond_out
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method
