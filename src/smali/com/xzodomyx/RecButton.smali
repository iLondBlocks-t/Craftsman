.class public Lcom/xzodomyx/RecButton;
.super Landroid/view/View;
.source "RecButton.java"

# Feature A -- the Start control.
#
# Touch: hosted in a PopupWindow (finding A -- a plain decor-view child would
# never receive touch on this NativeActivity). The PopupWindow is sized WRAP_CONTENT
# around this view, so the touchable window is exactly the size of the visible icon:
# a tight hit-box with no oversized invisible zone stealing taps from the game.
#
# It tracks its OWN pointer id, so a finger already down elsewhere (look-drag,
# movement) can never be confused with a press on this button, and a press here
# is only completed by the same finger that started it.

# instance fields
.field private mDown:Z

.field private mFill:Landroid/graphics/Paint;

.field private mPointerId:I

.field private mRing:Landroid/graphics/Paint;


# direct methods
.method public constructor <init>(Landroid/content/Context;)V
    .locals 4

    invoke-direct {p0, p1}, Landroid/view/View;-><init>(Landroid/content/Context;)V

    const/4 v0, -0x1

    iput v0, p0, Lcom/xzodomyx/RecButton;->mPointerId:I

    new-instance v1, Landroid/graphics/Paint;

    const/4 v2, 0x1

    invoke-direct {v1, v2}, Landroid/graphics/Paint;-><init>(I)V

    const v3, -0x33000000

    invoke-virtual {v1, v3}, Landroid/graphics/Paint;->setColor(I)V

    iput-object v1, p0, Lcom/xzodomyx/RecButton;->mRing:Landroid/graphics/Paint;

    new-instance v1, Landroid/graphics/Paint;

    invoke-direct {v1, v2}, Landroid/graphics/Paint;-><init>(I)V

    const v3, -0x33bc

    invoke-virtual {v1, v3}, Landroid/graphics/Paint;->setColor(I)V

    iput-object v1, p0, Lcom/xzodomyx/RecButton;->mFill:Landroid/graphics/Paint;

    return-void
.end method


# virtual methods
.method protected onMeasure(II)V
    .locals 3

    invoke-virtual {p0}, Lcom/xzodomyx/RecButton;->getResources()Landroid/content/res/Resources;

    move-result-object v0

    invoke-virtual {v0}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;

    move-result-object v0

    iget v0, v0, Landroid/util/DisplayMetrics;->density:F

    const/high16 v1, 0x42200000    # 40dp -- matches the drawn icon exactly

    mul-float/2addr v0, v1

    float-to-int v0, v0

    invoke-virtual {p0, v0, v0}, Lcom/xzodomyx/RecButton;->setMeasuredDimension(II)V

    return-void
.end method

.method protected onDraw(Landroid/graphics/Canvas;)V
    .locals 7

    :try_start_0
    invoke-virtual {p0}, Lcom/xzodomyx/RecButton;->getWidth()I

    move-result v0

    int-to-float v1, v0

    const/high16 v2, 0x40000000

    div-float v3, v1, v2           # cx = cy = w/2

    iget-boolean v4, p0, Lcom/xzodomyx/RecButton;->mDown:Z

    if-eqz v4, :cond_up

    const v4, 0x3f4ccccd           # pressed: 0.80 radius
    goto :goto_r

    :cond_up
    const v4, 0x3f666666           # idle: 0.90 radius

    :goto_r
    mul-float v5, v3, v4

    iget-object v6, p0, Lcom/xzodomyx/RecButton;->mRing:Landroid/graphics/Paint;

    invoke-virtual {p1, v3, v3, v5, v6}, Landroid/graphics/Canvas;->drawCircle(FFFLandroid/graphics/Paint;)V

    const v4, 0x3ecccccd           # inner red dot = 0.40 of the plate

    mul-float v5, v3, v4

    iget-object v6, p0, Lcom/xzodomyx/RecButton;->mFill:Landroid/graphics/Paint;

    invoke-virtual {p1, v3, v3, v5, v6}, Landroid/graphics/Canvas;->drawCircle(FFFLandroid/graphics/Paint;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method

.method public onTouchEvent(Landroid/view/MotionEvent;)Z
    .locals 8

    :try_start_0
    invoke-virtual {p1}, Landroid/view/MotionEvent;->getActionMasked()I

    move-result v0

    invoke-virtual {p1}, Landroid/view/MotionEvent;->getActionIndex()I

    move-result v1

    invoke-virtual {p1, v1}, Landroid/view/MotionEvent;->getPointerId(I)I

    move-result v2

    iget v3, p0, Lcom/xzodomyx/RecButton;->mPointerId:I

    const/4 v4, 0x1

    const/4 v5, 0x0

    const/4 v6, -0x1

    # DOWN / POINTER_DOWN: claim this pointer only if we have none yet
    if-eqz v0, :cond_down

    const/4 v7, 0x5

    if-eq v0, v7, :cond_down

    goto :goto_notdown

    :cond_down
    if-ne v3, v6, :cond_ignore

    iput v2, p0, Lcom/xzodomyx/RecButton;->mPointerId:I

    iput-boolean v4, p0, Lcom/xzodomyx/RecButton;->mDown:Z

    invoke-virtual {p0}, Lcom/xzodomyx/RecButton;->invalidate()V

    return v4

    :goto_notdown
    # UP / POINTER_UP / CANCEL: only OUR pointer completes or cancels the press
    if-ne v3, v6, :cond_track

    return v5

    :cond_track
    if-eq v2, v3, :cond_mine

    return v5

    :cond_mine
    const/4 v7, 0x1

    if-eq v0, v7, :cond_release

    const/4 v7, 0x6

    if-eq v0, v7, :cond_release

    const/4 v7, 0x3

    if-eq v0, v7, :cond_cancel

    return v4

    :cond_release
    iput v6, p0, Lcom/xzodomyx/RecButton;->mPointerId:I

    iput-boolean v5, p0, Lcom/xzodomyx/RecButton;->mDown:Z

    invoke-virtual {p0}, Lcom/xzodomyx/RecButton;->invalidate()V

    invoke-static {}, Lcom/xzodomyx/Hud;->onRecTapped()V

    return v4

    :cond_cancel
    iput v6, p0, Lcom/xzodomyx/RecButton;->mPointerId:I

    iput-boolean v5, p0, Lcom/xzodomyx/RecButton;->mDown:Z

    invoke-virtual {p0}, Lcom/xzodomyx/RecButton;->invalidate()V

    return v4

    :cond_ignore
    return v5
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :catch_0
    move-exception v0

    const/4 v0, 0x0

    return v0
.end method
