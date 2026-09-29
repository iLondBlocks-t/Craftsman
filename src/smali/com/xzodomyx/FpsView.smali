.class public Lcom/xzodomyx/FpsView;
.super Landroid/view/View;
.source "FpsView.java"

# Feature C -- FPS readout drawn with the GAME'S OWN bitmap font.
#
# Font: assets/images/font/default8.png, which ships inside this APK already
# (128x128, a 16x16 grid of 8x8 glyphs indexed by character code). Reusing it
# guarantees the counter matches Minecraft's typography exactly and avoids
# introducing any external font asset.
#
# No background box: glyphs are blitted straight over the game, with a classic
# 1-pixel dark drop-shadow pass underneath purely for legibility on bright
# terrain -- the shadow is on the glyphs themselves, not a panel.
#
# Colour-coded by measured framerate (thresholds in setFps).
#
# Nearest-neighbour only (antialias/filter/dither all off) so the pixel art
# scales up crisply instead of turning blurry.


# instance fields
.field private mColor:I

.field private mDst:Landroid/graphics/Rect;

.field private mFont:Landroid/graphics/Bitmap;

.field private mMainFilter:Landroid/graphics/ColorFilter;

.field private mPaint:Landroid/graphics/Paint;

.field private mScale:I

.field private mShadowFilter:Landroid/graphics/ColorFilter;

.field private mSrc:Landroid/graphics/Rect;

.field private mText:Ljava/lang/String;


# direct methods
.method public constructor <init>(Landroid/content/Context;)V
    .locals 6

    invoke-direct {p0, p1}, Landroid/view/View;-><init>(Landroid/content/Context;)V

    new-instance v0, Landroid/graphics/Paint;

    invoke-direct {v0}, Landroid/graphics/Paint;-><init>()V

    const/4 v1, 0x0

    invoke-virtual {v0, v1}, Landroid/graphics/Paint;->setAntiAlias(Z)V

    invoke-virtual {v0, v1}, Landroid/graphics/Paint;->setFilterBitmap(Z)V

    invoke-virtual {v0, v1}, Landroid/graphics/Paint;->setDither(Z)V

    iput-object v0, p0, Lcom/xzodomyx/FpsView;->mPaint:Landroid/graphics/Paint;

    new-instance v0, Landroid/graphics/Rect;

    invoke-direct {v0}, Landroid/graphics/Rect;-><init>()V

    iput-object v0, p0, Lcom/xzodomyx/FpsView;->mSrc:Landroid/graphics/Rect;

    new-instance v0, Landroid/graphics/Rect;

    invoke-direct {v0}, Landroid/graphics/Rect;-><init>()V

    iput-object v0, p0, Lcom/xzodomyx/FpsView;->mDst:Landroid/graphics/Rect;

    const-string v0, "FPS --"

    iput-object v0, p0, Lcom/xzodomyx/FpsView;->mText:Ljava/lang/String;

    const v0, -0xaa00ab            # 0xFF55FF55 green

    iput v0, p0, Lcom/xzodomyx/FpsView;->mColor:I

    new-instance v2, Landroid/graphics/PorterDuffColorFilter;

    sget-object v3, Landroid/graphics/PorterDuff$Mode;->SRC_IN:Landroid/graphics/PorterDuff$Mode;

    invoke-direct {v2, v0, v3}, Landroid/graphics/PorterDuffColorFilter;-><init>(ILandroid/graphics/PorterDuff$Mode;)V

    iput-object v2, p0, Lcom/xzodomyx/FpsView;->mMainFilter:Landroid/graphics/ColorFilter;

    new-instance v2, Landroid/graphics/PorterDuffColorFilter;

    const v4, -0xc0c0c1            # 0xFF3F3F3F shadow

    invoke-direct {v2, v4, v3}, Landroid/graphics/PorterDuffColorFilter;-><init>(ILandroid/graphics/PorterDuff$Mode;)V

    iput-object v2, p0, Lcom/xzodomyx/FpsView;->mShadowFilter:Landroid/graphics/ColorFilter;

    # integer scale factor so glyphs stay pixel-exact
    invoke-virtual {p1}, Landroid/content/Context;->getResources()Landroid/content/res/Resources;

    move-result-object v2

    invoke-virtual {v2}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;

    move-result-object v2

    iget v2, v2, Landroid/util/DisplayMetrics;->density:F

    const/high16 v3, 0x40000000    # 2.0f

    mul-float/2addr v2, v3

    float-to-int v2, v2

    const/4 v3, 0x2

    invoke-static {v3, v2}, Ljava/lang/Math;->max(II)I

    move-result v2

    iput v2, p0, Lcom/xzodomyx/FpsView;->mScale:I

    # load the game's own font atlas out of its assets
    :try_start_0
    invoke-virtual {p1}, Landroid/content/Context;->getAssets()Landroid/content/res/AssetManager;

    move-result-object v2

    const-string v3, "images/font/default8.png"

    invoke-virtual {v2, v3}, Landroid/content/res/AssetManager;->open(Ljava/lang/String;)Ljava/io/InputStream;

    move-result-object v2

    new-instance v3, Landroid/graphics/BitmapFactory$Options;

    invoke-direct {v3}, Landroid/graphics/BitmapFactory$Options;-><init>()V

    iput-boolean v1, v3, Landroid/graphics/BitmapFactory$Options;->inScaled:Z

    const/4 v4, 0x0

    invoke-static {v2, v4, v3}, Landroid/graphics/BitmapFactory;->decodeStream(Ljava/io/InputStream;Landroid/graphics/Rect;Landroid/graphics/BitmapFactory$Options;)Landroid/graphics/Bitmap;

    move-result-object v4

    iput-object v4, p0, Lcom/xzodomyx/FpsView;->mFont:Landroid/graphics/Bitmap;

    invoke-virtual {v2}, Ljava/io/InputStream;->close()V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v2

    const/4 v2, 0x0

    iput-object v2, p0, Lcom/xzodomyx/FpsView;->mFont:Landroid/graphics/Bitmap;

    return-void
.end method

.method private drawPass(Landroid/graphics/Canvas;IILandroid/graphics/ColorFilter;)V
    .locals 11

    # NOTE: .locals must stay <= 11 here. With 5 parameter registers (p0..p4),
    # 12 locals would place p4 at v16, past the 4-bit limit of invoke/iput.
    # Rect fields are written directly instead of via set(IIII) so the loop
    # needs only a single scratch register.

    iget-object v0, p0, Lcom/xzodomyx/FpsView;->mPaint:Landroid/graphics/Paint;

    invoke-virtual {v0, p4}, Landroid/graphics/Paint;->setColorFilter(Landroid/graphics/ColorFilter;)Landroid/graphics/ColorFilter;

    iget-object v1, p0, Lcom/xzodomyx/FpsView;->mFont:Landroid/graphics/Bitmap;

    iget v2, p0, Lcom/xzodomyx/FpsView;->mScale:I

    iget-object v3, p0, Lcom/xzodomyx/FpsView;->mText:Ljava/lang/String;

    iget-object v4, p0, Lcom/xzodomyx/FpsView;->mSrc:Landroid/graphics/Rect;

    iget-object v5, p0, Lcom/xzodomyx/FpsView;->mDst:Landroid/graphics/Rect;

    move v6, p2

    const/4 v7, 0x0

    :goto_0
    invoke-virtual {v3}, Ljava/lang/String;->length()I

    move-result v8

    if-ge v7, v8, :cond_done

    invoke-virtual {v3, v7}, Ljava/lang/String;->charAt(I)C

    move-result v8

    # atlas cell: column = code & 15, row = code >> 4, each cell 8x8
    and-int/lit8 v9, v8, 0xf

    mul-int/lit8 v9, v9, 0x8

    shr-int/lit8 v8, v8, 0x4

    mul-int/lit8 v8, v8, 0x8

    iput v9, v4, Landroid/graphics/Rect;->left:I

    iput v8, v4, Landroid/graphics/Rect;->top:I

    add-int/lit8 v10, v9, 0x8

    iput v10, v4, Landroid/graphics/Rect;->right:I

    add-int/lit8 v10, v8, 0x8

    iput v10, v4, Landroid/graphics/Rect;->bottom:I

    iput v6, v5, Landroid/graphics/Rect;->left:I

    iput p3, v5, Landroid/graphics/Rect;->top:I

    mul-int/lit8 v10, v2, 0x8

    add-int/2addr v10, v6

    iput v10, v5, Landroid/graphics/Rect;->right:I

    mul-int/lit8 v10, v2, 0x8

    add-int/2addr v10, p3

    iput v10, v5, Landroid/graphics/Rect;->bottom:I

    invoke-virtual {p1, v1, v4, v5, v0}, Landroid/graphics/Canvas;->drawBitmap(Landroid/graphics/Bitmap;Landroid/graphics/Rect;Landroid/graphics/Rect;Landroid/graphics/Paint;)V

    # 6px advance matches the game's own default glyph advance
    mul-int/lit8 v10, v2, 0x6

    add-int/2addr v6, v10

    add-int/lit8 v7, v7, 0x1

    goto :goto_0

    :cond_done
    return-void
.end method


# virtual methods
.method public setLabel(Ljava/lang/String;I)V
    .locals 3

    iput-object p1, p0, Lcom/xzodomyx/FpsView;->mText:Ljava/lang/String;

    iput p2, p0, Lcom/xzodomyx/FpsView;->mColor:I

    new-instance v0, Landroid/graphics/PorterDuffColorFilter;

    sget-object v1, Landroid/graphics/PorterDuff$Mode;->SRC_IN:Landroid/graphics/PorterDuff$Mode;

    invoke-direct {v0, p2, v1}, Landroid/graphics/PorterDuffColorFilter;-><init>(ILandroid/graphics/PorterDuff$Mode;)V

    iput-object v0, p0, Lcom/xzodomyx/FpsView;->mMainFilter:Landroid/graphics/ColorFilter;

    invoke-virtual {p0}, Lcom/xzodomyx/FpsView;->requestLayout()V

    invoke-virtual {p0}, Lcom/xzodomyx/FpsView;->invalidate()V

    return-void
.end method

.method public setPixelScale(I)V
    .locals 0

    iput p1, p0, Lcom/xzodomyx/FpsView;->mScale:I

    invoke-virtual {p0}, Lcom/xzodomyx/FpsView;->requestLayout()V

    invoke-virtual {p0}, Lcom/xzodomyx/FpsView;->invalidate()V

    return-void
.end method

.method public setFps(I)V
    .locals 5

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "FPS "

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    iput-object v0, p0, Lcom/xzodomyx/FpsView;->mText:Ljava/lang/String;

    # thresholds: <30 red, 30..50 yellow, >50 green
    const/16 v1, 0x1e

    if-ge p1, v1, :cond_mid

    const v2, -0xaaab              # 0xFFFF5555 red

    goto :goto_set

    :cond_mid
    const/16 v1, 0x32

    if-gt p1, v1, :cond_good

    const v2, -0x5600              # 0xFFFFAA00 yellow

    goto :goto_set

    :cond_good
    const v2, -0xaa00ab            # 0xFF55FF55 green

    :goto_set
    iget v3, p0, Lcom/xzodomyx/FpsView;->mColor:I

    iput v2, p0, Lcom/xzodomyx/FpsView;->mColor:I

    # only rebuild the filter when the colour band actually changes
    if-eq v3, v2, :cond_same

    new-instance v4, Landroid/graphics/PorterDuffColorFilter;

    sget-object v1, Landroid/graphics/PorterDuff$Mode;->SRC_IN:Landroid/graphics/PorterDuff$Mode;

    invoke-direct {v4, v2, v1}, Landroid/graphics/PorterDuffColorFilter;-><init>(ILandroid/graphics/PorterDuff$Mode;)V

    iput-object v4, p0, Lcom/xzodomyx/FpsView;->mMainFilter:Landroid/graphics/ColorFilter;

    :cond_same
    invoke-virtual {p0}, Lcom/xzodomyx/FpsView;->requestLayout()V

    invoke-virtual {p0}, Lcom/xzodomyx/FpsView;->invalidate()V

    return-void
.end method

.method protected onMeasure(II)V
    .locals 4

    iget-object v0, p0, Lcom/xzodomyx/FpsView;->mText:Ljava/lang/String;

    invoke-virtual {v0}, Ljava/lang/String;->length()I

    move-result v0

    iget v1, p0, Lcom/xzodomyx/FpsView;->mScale:I

    mul-int/lit8 v2, v1, 0x6

    mul-int/2addr v0, v2

    add-int/2addr v0, v1

    mul-int/lit8 v2, v1, 0x8

    add-int/2addr v2, v1

    invoke-virtual {p0, v0, v2}, Lcom/xzodomyx/FpsView;->setMeasuredDimension(II)V

    return-void
.end method

.method protected onDraw(Landroid/graphics/Canvas;)V
    .locals 4

    :try_start_0
    iget-object v0, p0, Lcom/xzodomyx/FpsView;->mFont:Landroid/graphics/Bitmap;

    if-eqz v0, :cond_out

    iget v1, p0, Lcom/xzodomyx/FpsView;->mScale:I

    iget-object v2, p0, Lcom/xzodomyx/FpsView;->mShadowFilter:Landroid/graphics/ColorFilter;

    invoke-direct {p0, p1, v1, v1, v2}, Lcom/xzodomyx/FpsView;->drawPass(Landroid/graphics/Canvas;IILandroid/graphics/ColorFilter;)V

    const/4 v3, 0x0

    iget-object v2, p0, Lcom/xzodomyx/FpsView;->mMainFilter:Landroid/graphics/ColorFilter;

    invoke-direct {p0, p1, v3, v3, v2}, Lcom/xzodomyx/FpsView;->drawPass(Landroid/graphics/Canvas;IILandroid/graphics/ColorFilter;)V

    :cond_out
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method
