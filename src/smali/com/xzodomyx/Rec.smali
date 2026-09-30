.class public Lcom/xzodomyx/Rec;
.super Landroid/content/BroadcastReceiver;
.source "Rec.java"

# Feature A -- local gameplay recording to .mp4.
#
# PIPELINE (all hardware, zero CPU frame copies):
#
#   MediaProjection -> VirtualDisplay -> MediaCodec input Surface
#                   -> H.264 (hardware) -> MediaMuxer -> local .mp4
#
# Why this and not glReadPixels: MainActivity is a NativeActivity, so the GL
# context belongs to a native render thread that Java cannot touch. A
# glReadPixels hook would have to run ON the game's render thread, stalling the
# GPU pipeline every frame. This path never runs a single instruction on the
# game's render thread -- the compositor feeds the encoder directly, so the
# recorder adds no per-frame work to the game at all. That is the strongest
# possible form of "recording never makes an already-laggy session worse".
#
# The encoder drain loop runs on its own thread. Everything is wrapped so a
# recording failure can never crash or freeze gameplay -- worst case recording
# stops and the user is told.
#
# This class is also the BroadcastReceiver for the notification Stop action,
# and the Runnable for the drain loop, to keep the added class count minimal.

.implements Ljava/lang/Runnable;


# static fields
.field static sAct:Landroid/app/Activity;

.field static sCodec:Landroid/media/MediaCodec;

.field static sCodecName:Ljava/lang/String;

.field static sFps:I

.field static sH:I

.field static sLowLag:Z

.field static sW:I

.field static sMuxer:Landroid/media/MediaMuxer;

.field static sMuxing:Z

.field static sGap:Z

.field static sMaxW:I

.field static sPath:Ljava/lang/String;

.field static sPausePtsUs:J

.field static sPaused:Z

.field static sSkipUs:J

.field static sProj:Landroid/media/projection/MediaProjection;

.field static sProjCode:I

.field static sProjData:Landroid/content/Intent;

.field static sRec:Z

.field static sRegistered:Z

.field static sStop:Z

.field static sTrack:I

.field static sVd:Landroid/hardware/display/VirtualDisplay;


# direct methods
.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Landroid/content/BroadcastReceiver;-><init>()V

    return-void
.end method

.method public static setProjection(ILandroid/content/Intent;)V
    .locals 0

    sput p0, Lcom/xzodomyx/Rec;->sProjCode:I

    sput-object p1, Lcom/xzodomyx/Rec;->sProjData:Landroid/content/Intent;

    return-void
.end method

.method public static hasProjection()Z
    .locals 2

    sget-object v0, Lcom/xzodomyx/Rec;->sProjData:Landroid/content/Intent;

    if-nez v0, :cond_no

    const/4 v1, 0x1

    return v1

    :cond_no
    const/4 v1, 0x0

    return v1
.end method

.method public static isRecording()Z
    .locals 1

    sget-boolean v0, Lcom/xzodomyx/Rec;->sRec:Z

    return v0
.end method

.method static toast(Ljava/lang/String;)V
    .locals 3

    :try_start_0
    sget-object v0, Lcom/xzodomyx/Rec;->sAct:Landroid/app/Activity;

    if-eqz v0, :cond_out

    const/4 v1, 0x1

    invoke-static {v0, p0, v1}, Landroid/widget/Toast;->makeText(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;

    move-result-object v2

    invoke-virtual {v2}, Landroid/widget/Toast;->show()V

    :cond_out
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method

# Starts capture. Returns true only if the whole chain came up.
.method public static start(Landroid/app/Activity;)Z
    .locals 15

    sget-boolean v0, Lcom/xzodomyx/Rec;->sRec:Z

    if-eqz v0, :cond_go

    const/4 v0, 0x0

    return v0

    :cond_go
    sput-object p0, Lcom/xzodomyx/Rec;->sAct:Landroid/app/Activity;

    :try_start_0
    # MediaProjection is API 21+. Below that the feature simply does not arm.
    sget v0, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v1, 0x15

    if-ge v0, v1, :cond_api

    const-string v0, "Recording needs Android 5.0+"

    invoke-static {v0}, Lcom/xzodomyx/Rec;->toast(Ljava/lang/String;)V

    const/4 v0, 0x0

    return v0

    :cond_api
    sget-object v0, Lcom/xzodomyx/Rec;->sProjData:Landroid/content/Intent;

    if-nez v0, :cond_have

    const-string v0, "Enable Record gameplay on the launcher screen first"

    invoke-static {v0}, Lcom/xzodomyx/Rec;->toast(Ljava/lang/String;)V

    const/4 v0, 0x0

    return v0

    :cond_have
    # ---- resolve capture size from the real display ----
    invoke-virtual {p0}, Landroid/app/Activity;->getResources()Landroid/content/res/Resources;

    move-result-object v1

    invoke-virtual {v1}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;

    move-result-object v1

    iget v2, v1, Landroid/util/DisplayMetrics;->widthPixels:I

    iget v3, v1, Landroid/util/DisplayMetrics;->heightPixels:I

    iget v4, v1, Landroid/util/DisplayMetrics;->densityDpi:I

    # halve until <=1280 wide: keeps bitrate and encoder load sane on old devices
    :goto_shrink
    sget v5, Lcom/xzodomyx/Rec;->sMaxW:I

    if-gtz v5, :cond_havecap

    const/16 v5, 0x500

    :cond_havecap

    if-le v2, v5, :cond_size

    div-int/lit8 v2, v2, 0x2

    div-int/lit8 v3, v3, 0x2

    goto :goto_shrink

    :cond_size
    # H.264 requires even dimensions
    and-int/lit8 v2, v2, -0x2

    and-int/lit8 v3, v3, -0x2

    sput v2, Lcom/xzodomyx/Rec;->sW:I

    sput v3, Lcom/xzodomyx/Rec;->sH:I

    # ---- output path ----
    const-string v5, "Movies"

    invoke-static {v5}, Landroid/os/Environment;->getExternalStoragePublicDirectory(Ljava/lang/String;)Ljava/io/File;

    move-result-object v5

    new-instance v6, Ljava/io/File;

    const-string v7, "XZO-Domyx"

    invoke-direct {v6, v5, v7}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V

    invoke-virtual {v6}, Ljava/io/File;->mkdirs()Z

    new-instance v7, Ljava/lang/StringBuilder;

    invoke-direct {v7}, Ljava/lang/StringBuilder;-><init>()V

    const-string v8, "xzo_"

    invoke-virtual {v7, v8}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J

    move-result-wide v9

    invoke-virtual {v7, v9, v10}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;

    const-string v8, ".mp4"

    invoke-virtual {v7, v8}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v7}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v7

    new-instance v8, Ljava/io/File;

    invoke-direct {v8, v6, v7}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V

    invoke-virtual {v8}, Ljava/io/File;->getAbsolutePath()Ljava/lang/String;

    move-result-object v7

    sput-object v7, Lcom/xzodomyx/Rec;->sPath:Ljava/lang/String;

    # ---- encoder: H.264, Surface input (no CPU frame copies) ----
    const-string v5, "video/avc"

    invoke-static {v5, v2, v3}, Landroid/media/MediaFormat;->createVideoFormat(Ljava/lang/String;II)Landroid/media/MediaFormat;

    move-result-object v6

    const-string v9, "color-format"

    const v10, 0x7f000789          # COLOR_FormatSurface

    invoke-virtual {v6, v9, v10}, Landroid/media/MediaFormat;->setInteger(Ljava/lang/String;I)V

    const-string v9, "bitrate"

    mul-int v10, v2, v3

    sget-boolean v11, Lcom/xzodomyx/Rec;->sLowLag:Z

    if-eqz v11, :cond_bithi

    mul-int/lit8 v10, v10, 0x2

    goto :goto_bit

    :cond_bithi
    mul-int/lit8 v10, v10, 0x4

    :goto_bit

    invoke-virtual {v6, v9, v10}, Landroid/media/MediaFormat;->setInteger(Ljava/lang/String;I)V

    const-string v9, "frame-rate"

    sget-boolean v11, Lcom/xzodomyx/Rec;->sLowLag:Z

    if-eqz v11, :cond_fps30

    const/16 v10, 0x18             # 24 fps

    goto :goto_fps

    :cond_fps30
    const/16 v10, 0x1e             # 30 fps

    :goto_fps
    sput v10, Lcom/xzodomyx/Rec;->sFps:I

    invoke-virtual {v6, v9, v10}, Landroid/media/MediaFormat;->setInteger(Ljava/lang/String;I)V

    const-string v9, "i-frame-interval"

    const/4 v10, 0x5

    invoke-virtual {v6, v9, v10}, Landroid/media/MediaFormat;->setInteger(Ljava/lang/String;I)V

    # don't re-encode anything while the picture is static: the VirtualDisplay
    # only produces a frame when the screen actually changes, so without this
    # the muxer sees long gaps. 200ms == 5fps floor on a still screen.
    const-string v9, "repeat-previous-frame-after"

    const-wide/32 v10, 0x30d40

    invoke-virtual {v6, v9, v10, v11}, Landroid/media/MediaFormat;->setLong(Ljava/lang/String;J)V

    invoke-static {v5}, Lcom/xzodomyx/Rec;->makeCodec(Ljava/lang/String;)Landroid/media/MediaCodec;

    move-result-object v5

    sput-object v5, Lcom/xzodomyx/Rec;->sCodec:Landroid/media/MediaCodec;

    const/4 v9, 0x0

    const/4 v10, 0x1               # CONFIGURE_FLAG_ENCODE

    invoke-virtual {v5, v6, v9, v9, v10}, Landroid/media/MediaCodec;->configure(Landroid/media/MediaFormat;Landroid/view/Surface;Landroid/media/MediaCrypto;I)V

    invoke-virtual {v5}, Landroid/media/MediaCodec;->createInputSurface()Landroid/view/Surface;

    move-result-object v6

    invoke-virtual {v5}, Landroid/media/MediaCodec;->start()V

    # ---- muxer ----
    new-instance v9, Landroid/media/MediaMuxer;

    const/4 v10, 0x0               # MUXER_OUTPUT_MPEG_4

    invoke-direct {v9, v7, v10}, Landroid/media/MediaMuxer;-><init>(Ljava/lang/String;I)V

    sput-object v9, Lcom/xzodomyx/Rec;->sMuxer:Landroid/media/MediaMuxer;

    const/4 v10, 0x0

    sput-boolean v10, Lcom/xzodomyx/Rec;->sMuxing:Z

    const/4 v10, -0x1

    sput v10, Lcom/xzodomyx/Rec;->sTrack:I

    # ---- projection + virtual display ----
    const-string v10, "media_projection"

    invoke-virtual {p0, v10}, Landroid/app/Activity;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v10

    check-cast v10, Landroid/media/projection/MediaProjectionManager;

    sget v11, Lcom/xzodomyx/Rec;->sProjCode:I

    sget-object v12, Lcom/xzodomyx/Rec;->sProjData:Landroid/content/Intent;

    invoke-virtual {v10, v11, v12}, Landroid/media/projection/MediaProjectionManager;->getMediaProjection(ILandroid/content/Intent;)Landroid/media/projection/MediaProjection;

    move-result-object v10

    sput-object v10, Lcom/xzodomyx/Rec;->sProj:Landroid/media/projection/MediaProjection;

    if-nez v10, :cond_proj

    const-string v0, "Screen capture permission was declined"

    invoke-static {v0}, Lcom/xzodomyx/Rec;->toast(Ljava/lang/String;)V

    invoke-static {}, Lcom/xzodomyx/Rec;->release()V

    const/4 v0, 0x0

    return v0

    :cond_proj
    # 7 args: needs the /range form over CONSECUTIVE registers. v7 (the path
    # string) and v9 (the muxer) are both already stored in statics by now, so
    # v7..v13 is free to reuse as the argument block.
    move-object v7, v10            # MediaProjection

    const-string v8, "xzo-domyx"

    move v9, v2                    # width

    move v10, v3                   # height

    move v11, v4                   # dpi

    const/16 v12, 0x10             # VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR

    move-object v13, v6            # encoder input surface

    invoke-static/range {v7 .. v13}, Lcom/xzodomyx/Rec;->makeVd(Landroid/media/projection/MediaProjection;Ljava/lang/String;IIIILandroid/view/Surface;)Landroid/hardware/display/VirtualDisplay;

    move-result-object v0

    sput-object v0, Lcom/xzodomyx/Rec;->sVd:Landroid/hardware/display/VirtualDisplay;

    # ---- arm and spin up the drain thread ----
    const/4 v0, 0x0

    sput-boolean v0, Lcom/xzodomyx/Rec;->sStop:Z

    const/4 v0, 0x1

    sput-boolean v0, Lcom/xzodomyx/Rec;->sRec:Z

    const/4 v0, 0x0

    sput-boolean v0, Lcom/xzodomyx/Rec;->sPaused:Z

    sput-boolean v0, Lcom/xzodomyx/Rec;->sGap:Z

    const-wide/16 v9, 0x0

    sput-wide v9, Lcom/xzodomyx/Rec;->sSkipUs:J

    sput-wide v9, Lcom/xzodomyx/Rec;->sPausePtsUs:J

    const/4 v0, 0x1

    new-instance v0, Lcom/xzodomyx/Rec;

    invoke-direct {v0}, Lcom/xzodomyx/Rec;-><init>()V

    new-instance v1, Ljava/lang/Thread;

    const-string v5, "xzo-rec"

    invoke-direct {v1, v0, v5}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;Ljava/lang/String;)V

    const/16 v5, 0xa               # THREAD_PRIORITY_BACKGROUND

    invoke-virtual {v1, v5}, Ljava/lang/Thread;->setPriority(I)V

    invoke-virtual {v1}, Ljava/lang/Thread;->start()V

    # Report the negotiated size, rate and encoder name. There is no device in
    # the build environment, so this toast is the only way to find out whether
    # the phone handed us a hardware or a software encoder.
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v5, "REC "

    invoke-virtual {v0, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    sget v5, Lcom/xzodomyx/Rec;->sW:I

    invoke-virtual {v0, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    const-string v5, "x"

    invoke-virtual {v0, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    sget v5, Lcom/xzodomyx/Rec;->sH:I

    invoke-virtual {v0, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    const-string v5, " @"

    invoke-virtual {v0, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    sget v5, Lcom/xzodomyx/Rec;->sFps:I

    invoke-virtual {v0, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    const-string v5, "fps\n"

    invoke-virtual {v0, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    sget-object v5, Lcom/xzodomyx/Rec;->sCodecName:Ljava/lang/String;

    invoke-virtual {v0, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lcom/xzodomyx/Rec;->toast(Ljava/lang/String;)V

    invoke-static {p0}, Lcom/xzodomyx/Rec;->notif(Landroid/app/Activity;)V

    const/4 v0, 0x1

    return v0
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :catch_0
    move-exception v0

    const-string v1, "Could not start recording"

    invoke-static {v1}, Lcom/xzodomyx/Rec;->toast(Ljava/lang/String;)V

    invoke-static {}, Lcom/xzodomyx/Rec;->release()V

    const/4 v0, 0x0

    return v0
.end method

# split out so `start` stays inside the 16-register window
.method static makeVd(Landroid/media/projection/MediaProjection;Ljava/lang/String;IIIILandroid/view/Surface;)Landroid/hardware/display/VirtualDisplay;
    .locals 9

    const/4 v8, 0x0

    move-object v0, p0

    move-object v1, p1

    move v2, p2

    move v3, p3

    move v4, p4

    move v5, p5

    move-object v6, p6

    move-object v7, v8

    invoke-virtual/range {v0 .. v8}, Landroid/media/projection/MediaProjection;->createVirtualDisplay(Ljava/lang/String;IIIILandroid/view/Surface;Landroid/hardware/display/VirtualDisplay$Callback;Landroid/os/Handler;)Landroid/hardware/display/VirtualDisplay;

    move-result-object v0

    return-object v0
.end method

.method static pickEncoderName()Ljava/lang/String;
    .locals 11

    # createEncoderByType() returns whatever the platform lists FIRST for
    # video/avc, and on plenty of mid-range devices that is the Google software
    # encoder. Software-encoding 30fps on the same cores the game is running on
    # is exactly the stutter being reported, so walk the list and take a real
    # hardware encoder instead.
    const/4 v0, 0x0

    :try_start_0
    invoke-static {}, Landroid/media/MediaCodecList;->getCodecCount()I

    move-result v1

    const/4 v2, 0x0

    :goto_i
    if-ge v2, v1, :cond_done

    invoke-static {v2}, Landroid/media/MediaCodecList;->getCodecInfoAt(I)Landroid/media/MediaCodecInfo;

    move-result-object v3

    invoke-virtual {v3}, Landroid/media/MediaCodecInfo;->isEncoder()Z

    move-result v10

    if-eqz v10, :cond_next

    invoke-virtual {v3}, Landroid/media/MediaCodecInfo;->getName()Ljava/lang/String;

    move-result-object v4

    const-string v9, "OMX.google."

    invoke-virtual {v4, v9}, Ljava/lang/String;->startsWith(Ljava/lang/String;)Z

    move-result v10

    if-nez v10, :cond_next

    const-string v9, "c2.android."

    invoke-virtual {v4, v9}, Ljava/lang/String;->startsWith(Ljava/lang/String;)Z

    move-result v10

    if-nez v10, :cond_next

    invoke-virtual {v3}, Landroid/media/MediaCodecInfo;->getSupportedTypes()[Ljava/lang/String;

    move-result-object v5

    array-length v6, v5

    const/4 v7, 0x0

    :goto_t
    if-ge v7, v6, :cond_next

    aget-object v8, v5, v7

    const-string v9, "video/avc"

    invoke-virtual {v9, v8}, Ljava/lang/String;->equalsIgnoreCase(Ljava/lang/String;)Z

    move-result v10

    if-eqz v10, :cond_tnext

    move-object v0, v4

    goto :cond_done

    :cond_tnext
    add-int/lit8 v7, v7, 0x1

    goto :goto_t

    :cond_next
    add-int/lit8 v2, v2, 0x1

    goto :goto_i

    :cond_done
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :goto_ret
    return-object v0

    :catch_0
    move-exception v1

    const/4 v0, 0x0

    goto :goto_ret
.end method

.method static makeCodec(Ljava/lang/String;)Landroid/media/MediaCodec;
    .locals 3

    invoke-static {}, Lcom/xzodomyx/Rec;->pickEncoderName()Ljava/lang/String;

    move-result-object v0

    if-eqz v0, :cond_bytype

    :try_start_0
    invoke-static {v0}, Landroid/media/MediaCodec;->createByCodecName(Ljava/lang/String;)Landroid/media/MediaCodec;

    move-result-object v1

    sput-object v0, Lcom/xzodomyx/Rec;->sCodecName:Ljava/lang/String;
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-object v1

    :catch_0
    move-exception v2

    :cond_bytype
    # fall back to the platform default rather than failing to record at all
    invoke-static {p0}, Landroid/media/MediaCodec;->createEncoderByType(Ljava/lang/String;)Landroid/media/MediaCodec;

    move-result-object v1

    const-string v0, "default"

    sput-object v0, Lcom/xzodomyx/Rec;->sCodecName:Ljava/lang/String;

    return-object v1
.end method

.method public static setPaused(Z)V
    .locals 4

    :try_start_0
    sget-boolean v0, Lcom/xzodomyx/Rec;->sRec:Z

    if-eqz v0, :cond_out

    sput-boolean p0, Lcom/xzodomyx/Rec;->sPaused:Z

    if-nez p0, :cond_out

    # coming back into the game: the frames we dropped may have been the
    # reference frames for what follows, so ask the encoder for a fresh
    # keyframe rather than letting the next GOP decode into garbage.
    sget-object v0, Lcom/xzodomyx/Rec;->sCodec:Landroid/media/MediaCodec;

    if-eqz v0, :cond_out

    new-instance v1, Landroid/os/Bundle;

    invoke-direct {v1}, Landroid/os/Bundle;-><init>()V

    const-string v2, "request-sync"

    const/4 v3, 0x0

    invoke-virtual {v1, v2, v3}, Landroid/os/Bundle;->putInt(Ljava/lang/String;I)V

    invoke-virtual {v0, v1}, Landroid/media/MediaCodec;->setParameters(Landroid/os/Bundle;)V

    :cond_out
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method

.method public static stop()V
    .locals 1

    sget-boolean v0, Lcom/xzodomyx/Rec;->sRec:Z

    if-eqz v0, :cond_out

    # the drain thread sees this, signals EOS, flushes and finalizes the file
    const/4 v0, 0x1

    sput-boolean v0, Lcom/xzodomyx/Rec;->sStop:Z

    :cond_out
    return-void
.end method

.method static release()V
    .locals 2

    :try_start_0
    sget-object v0, Lcom/xzodomyx/Rec;->sVd:Landroid/hardware/display/VirtualDisplay;

    if-eqz v0, :cond_0

    invoke-virtual {v0}, Landroid/hardware/display/VirtualDisplay;->release()V

    :cond_0
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :goto_0
    :try_start_1
    sget-object v0, Lcom/xzodomyx/Rec;->sCodec:Landroid/media/MediaCodec;

    if-eqz v0, :cond_1

    invoke-virtual {v0}, Landroid/media/MediaCodec;->stop()V

    invoke-virtual {v0}, Landroid/media/MediaCodec;->release()V

    :cond_1
    :try_end_1
    .catch Ljava/lang/Throwable; {:try_start_1 .. :try_end_1} :catch_1

    :goto_1
    :try_start_2
    sget-object v0, Lcom/xzodomyx/Rec;->sMuxer:Landroid/media/MediaMuxer;

    if-eqz v0, :cond_2

    sget-boolean v1, Lcom/xzodomyx/Rec;->sMuxing:Z

    if-eqz v1, :cond_2

    invoke-virtual {v0}, Landroid/media/MediaMuxer;->stop()V

    :cond_2
    if-eqz v0, :cond_3

    invoke-virtual {v0}, Landroid/media/MediaMuxer;->release()V

    :cond_3
    :try_end_2
    .catch Ljava/lang/Throwable; {:try_start_2 .. :try_end_2} :catch_2

    :goto_2
    :try_start_3
    sget-object v0, Lcom/xzodomyx/Rec;->sProj:Landroid/media/projection/MediaProjection;

    if-eqz v0, :cond_4

    invoke-virtual {v0}, Landroid/media/projection/MediaProjection;->stop()V

    :cond_4
    :try_end_3
    .catch Ljava/lang/Throwable; {:try_start_3 .. :try_end_3} :catch_3

    :goto_3
    const/4 v0, 0x0

    sput-object v0, Lcom/xzodomyx/Rec;->sVd:Landroid/hardware/display/VirtualDisplay;

    sput-object v0, Lcom/xzodomyx/Rec;->sCodec:Landroid/media/MediaCodec;

    sput-object v0, Lcom/xzodomyx/Rec;->sMuxer:Landroid/media/MediaMuxer;

    sput-object v0, Lcom/xzodomyx/Rec;->sProj:Landroid/media/projection/MediaProjection;

    const/4 v1, 0x0

    sput-boolean v1, Lcom/xzodomyx/Rec;->sRec:Z

    sput-boolean v1, Lcom/xzodomyx/Rec;->sMuxing:Z

    return-void

    :catch_0
    move-exception v0

    goto :goto_0

    :catch_1
    move-exception v0

    goto :goto_1

    :catch_2
    move-exception v0

    goto :goto_2

    :catch_3
    move-exception v0

    goto :goto_3
.end method

.method static notif(Landroid/app/Activity;)V
    .locals 8

    :try_start_0
    sget-boolean v0, Lcom/xzodomyx/Rec;->sRegistered:Z

    if-nez v0, :cond_reg

    new-instance v0, Lcom/xzodomyx/Rec;

    invoke-direct {v0}, Lcom/xzodomyx/Rec;-><init>()V

    new-instance v1, Landroid/content/IntentFilter;

    const-string v2, "com.xzodomyx.STOP"

    invoke-direct {v1, v2}, Landroid/content/IntentFilter;-><init>(Ljava/lang/String;)V

    invoke-virtual {p0, v0, v1}, Landroid/app/Activity;->registerReceiver(Landroid/content/BroadcastReceiver;Landroid/content/IntentFilter;)Landroid/content/Intent;

    const/4 v0, 0x1

    sput-boolean v0, Lcom/xzodomyx/Rec;->sRegistered:Z

    :cond_reg
    new-instance v0, Landroid/content/Intent;

    const-string v1, "com.xzodomyx.STOP"

    invoke-direct {v0, v1}, Landroid/content/Intent;-><init>(Ljava/lang/String;)V

    const/4 v1, 0x0

    const/high16 v2, 0x8000000     # FLAG_UPDATE_CURRENT

    invoke-static {p0, v1, v0, v2}, Landroid/app/PendingIntent;->getBroadcast(Landroid/content/Context;ILandroid/content/Intent;I)Landroid/app/PendingIntent;

    move-result-object v0

    new-instance v1, Landroid/app/Notification$Builder;

    invoke-direct {v1, p0}, Landroid/app/Notification$Builder;-><init>(Landroid/content/Context;)V

    const v2, 0x108003f            # android.R.drawable.ic_media_pause

    invoke-virtual {v1, v2}, Landroid/app/Notification$Builder;->setSmallIcon(I)Landroid/app/Notification$Builder;

    move-result-object v1

    const-string v2, "XZO-Domyx is recording"

    invoke-virtual {v1, v2}, Landroid/app/Notification$Builder;->setContentTitle(Ljava/lang/CharSequence;)Landroid/app/Notification$Builder;

    move-result-object v1

    const-string v2, "Tap to stop and save the video"

    invoke-virtual {v1, v2}, Landroid/app/Notification$Builder;->setContentText(Ljava/lang/CharSequence;)Landroid/app/Notification$Builder;

    move-result-object v1

    const/4 v2, 0x1

    invoke-virtual {v1, v2}, Landroid/app/Notification$Builder;->setOngoing(Z)Landroid/app/Notification$Builder;

    move-result-object v1

    invoke-virtual {v1, v0}, Landroid/app/Notification$Builder;->setContentIntent(Landroid/app/PendingIntent;)Landroid/app/Notification$Builder;

    move-result-object v1

    invoke-virtual {v1}, Landroid/app/Notification$Builder;->build()Landroid/app/Notification;

    move-result-object v1

    const-string v2, "notification"

    invoke-virtual {p0, v2}, Landroid/app/Activity;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Landroid/app/NotificationManager;

    const/16 v3, 0x7a69

    invoke-virtual {v2, v3, v1}, Landroid/app/NotificationManager;->notify(ILandroid/app/Notification;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method

.method static clearNotif()V
    .locals 3

    :try_start_0
    sget-object v0, Lcom/xzodomyx/Rec;->sAct:Landroid/app/Activity;

    if-eqz v0, :cond_out

    const-string v1, "notification"

    invoke-virtual {v0, v1}, Landroid/app/Activity;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Landroid/app/NotificationManager;

    const/16 v2, 0x7a69

    invoke-virtual {v1, v2}, Landroid/app/NotificationManager;->cancel(I)V

    :cond_out
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method


# virtual methods
.method public onReceive(Landroid/content/Context;Landroid/content/Intent;)V
    .locals 0

    invoke-static {}, Lcom/xzodomyx/Rec;->stop()V

    return-void
.end method

# Encoder drain loop. Runs on its own thread; never touches the game's threads.
.method public run()V
    .locals 12

    new-instance v0, Landroid/media/MediaCodec$BufferInfo;

    invoke-direct {v0}, Landroid/media/MediaCodec$BufferInfo;-><init>()V

    const/4 v1, 0x0                # signalled EOS yet?

    :goto_loop
    :try_start_0
    sget-object v2, Lcom/xzodomyx/Rec;->sCodec:Landroid/media/MediaCodec;

    if-eqz v2, :cond_done

    sget-boolean v3, Lcom/xzodomyx/Rec;->sStop:Z

    if-eqz v3, :cond_nosig

    if-nez v1, :cond_nosig

    invoke-virtual {v2}, Landroid/media/MediaCodec;->signalEndOfInputStream()V

    const/4 v1, 0x1

    :cond_nosig
    const-wide/32 v4, 0x186a0      # 100ms: block in the codec instead of
                                   # waking this thread 100x/second

    invoke-virtual {v2, v0, v4, v5}, Landroid/media/MediaCodec;->dequeueOutputBuffer(Landroid/media/MediaCodec$BufferInfo;J)I

    move-result v3

    const/4 v4, -0x2               # INFO_OUTPUT_FORMAT_CHANGED

    if-ne v3, v4, :cond_notfmt

    sget-boolean v4, Lcom/xzodomyx/Rec;->sMuxing:Z

    if-nez v4, :goto_loop

    invoke-virtual {v2}, Landroid/media/MediaCodec;->getOutputFormat()Landroid/media/MediaFormat;

    move-result-object v4

    sget-object v5, Lcom/xzodomyx/Rec;->sMuxer:Landroid/media/MediaMuxer;

    invoke-virtual {v5, v4}, Landroid/media/MediaMuxer;->addTrack(Landroid/media/MediaFormat;)I

    move-result v4

    sput v4, Lcom/xzodomyx/Rec;->sTrack:I

    invoke-virtual {v5}, Landroid/media/MediaMuxer;->start()V

    const/4 v4, 0x1

    sput-boolean v4, Lcom/xzodomyx/Rec;->sMuxing:Z

    goto :goto_loop

    :cond_notfmt
    if-gez v3, :cond_buf

    # INFO_TRY_AGAIN_LATER / BUFFERS_CHANGED: nothing to do this pass
    goto :goto_loop

    :cond_buf
    invoke-virtual {v2, v3}, Landroid/media/MediaCodec;->getOutputBuffer(I)Ljava/nio/ByteBuffer;

    move-result-object v6

    iget v7, v0, Landroid/media/MediaCodec$BufferInfo;->flags:I

    and-int/lit8 v8, v7, 0x2       # BUFFER_FLAG_CODEC_CONFIG -> not real frame data

    if-eqz v8, :cond_real

    const/4 v8, 0x0

    iput v8, v0, Landroid/media/MediaCodec$BufferInfo;->size:I

    :cond_real
    iget v8, v0, Landroid/media/MediaCodec$BufferInfo;->size:I

    if-lez v8, :cond_written

    sget-boolean v9, Lcom/xzodomyx/Rec;->sMuxing:Z

    if-eqz v9, :cond_written

    if-eqz v6, :cond_written

    # ---- "only the game" ----
    # Rec.setPaused() is driven by MainActivity onPause/onResume. While the game
    # is not in front, every frame the display produces is thrown away, so the
    # launcher, the notification shade, the home screen and any other app never
    # reach the file. The time spent away is then subtracted from the
    # presentation timestamps so the .mp4 has no frozen gap.
    sget-boolean v9, Lcom/xzodomyx/Rec;->sPaused:Z

    if-eqz v9, :cond_notpaused

    iget-wide v10, v0, Landroid/media/MediaCodec$BufferInfo;->presentationTimeUs:J

    sput-wide v10, Lcom/xzodomyx/Rec;->sPausePtsUs:J

    const/4 v9, 0x1

    sput-boolean v9, Lcom/xzodomyx/Rec;->sGap:Z

    goto :cond_written

    :cond_notpaused
    sget-boolean v9, Lcom/xzodomyx/Rec;->sGap:Z

    if-eqz v9, :cond_nogap

    const/4 v9, 0x0

    sput-boolean v9, Lcom/xzodomyx/Rec;->sGap:Z

    iget-wide v10, v0, Landroid/media/MediaCodec$BufferInfo;->presentationTimeUs:J

    sget-wide v4, Lcom/xzodomyx/Rec;->sPausePtsUs:J

    sub-long/2addr v10, v4

    sget-wide v4, Lcom/xzodomyx/Rec;->sSkipUs:J

    add-long/2addr v4, v10

    sput-wide v4, Lcom/xzodomyx/Rec;->sSkipUs:J

    :cond_nogap
    iget-wide v10, v0, Landroid/media/MediaCodec$BufferInfo;->presentationTimeUs:J

    sget-wide v4, Lcom/xzodomyx/Rec;->sSkipUs:J

    sub-long/2addr v10, v4

    iput-wide v10, v0, Landroid/media/MediaCodec$BufferInfo;->presentationTimeUs:J

    iget v9, v0, Landroid/media/MediaCodec$BufferInfo;->offset:I

    invoke-virtual {v6, v9}, Ljava/nio/ByteBuffer;->position(I)Ljava/nio/Buffer;

    iget v9, v0, Landroid/media/MediaCodec$BufferInfo;->offset:I

    add-int/2addr v9, v8

    invoke-virtual {v6, v9}, Ljava/nio/ByteBuffer;->limit(I)Ljava/nio/Buffer;

    sget-object v9, Lcom/xzodomyx/Rec;->sMuxer:Landroid/media/MediaMuxer;

    sget v10, Lcom/xzodomyx/Rec;->sTrack:I

    invoke-virtual {v9, v10, v6, v0}, Landroid/media/MediaMuxer;->writeSampleData(ILjava/nio/ByteBuffer;Landroid/media/MediaCodec$BufferInfo;)V

    :cond_written
    const/4 v9, 0x0

    invoke-virtual {v2, v3, v9}, Landroid/media/MediaCodec;->releaseOutputBuffer(IZ)V

    and-int/lit8 v9, v7, 0x4       # BUFFER_FLAG_END_OF_STREAM
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    if-eqz v9, :goto_loop

    :cond_done
    invoke-static {}, Lcom/xzodomyx/Rec;->finish()V

    return-void

    :catch_0
    move-exception v2

    # any failure: stop cleanly, tell the user, never propagate into the game
    invoke-static {}, Lcom/xzodomyx/Rec;->finish()V

    return-void

.end method

.method static finish()V
    .locals 4

    sget-object v0, Lcom/xzodomyx/Rec;->sPath:Ljava/lang/String;

    sget-boolean v1, Lcom/xzodomyx/Rec;->sMuxing:Z

    invoke-static {}, Lcom/xzodomyx/Rec;->release()V

    invoke-static {}, Lcom/xzodomyx/Rec;->clearNotif()V

    :try_start_0
    sget-object v2, Lcom/xzodomyx/Rec;->sAct:Landroid/app/Activity;

    if-eqz v2, :cond_out

    new-instance v3, Lcom/xzodomyx/Rec$1;

    invoke-direct {v3, v0, v1}, Lcom/xzodomyx/Rec$1;-><init>(Ljava/lang/String;Z)V

    invoke-virtual {v2, v3}, Landroid/app/Activity;->runOnUiThread(Ljava/lang/Runnable;)V

    :cond_out
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v2

    return-void
.end method
