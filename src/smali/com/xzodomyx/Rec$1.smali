.class Lcom/xzodomyx/Rec$1;
.super Ljava/lang/Object;
.source "Rec.java"

# Posts the end-of-recording result back on the UI thread: a toast with the
# saved path, plus a MediaScanner poke so the clip shows up in the gallery.

.implements Ljava/lang/Runnable;


# instance fields
.field final mOk:Z

.field final mPath:Ljava/lang/String;


# direct methods
.method constructor <init>(Ljava/lang/String;Z)V
    .locals 0

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/xzodomyx/Rec$1;->mPath:Ljava/lang/String;

    iput-boolean p2, p0, Lcom/xzodomyx/Rec$1;->mOk:Z

    return-void
.end method


# virtual methods
.method public run()V
    .locals 7

    :try_start_0
    iget-boolean v0, p0, Lcom/xzodomyx/Rec$1;->mOk:Z

    iget-object v1, p0, Lcom/xzodomyx/Rec$1;->mPath:Ljava/lang/String;

    if-eqz v0, :cond_fail

    if-eqz v1, :cond_fail

    sget-object v2, Lcom/xzodomyx/Rec;->sAct:Landroid/app/Activity;

    if-eqz v2, :cond_fail

    const/4 v3, 0x1

    new-array v3, v3, [Ljava/lang/String;

    const/4 v4, 0x0

    aput-object v1, v3, v4

    const/4 v5, 0x0

    invoke-static {v2, v3, v5, v5}, Landroid/media/MediaScannerConnection;->scanFile(Landroid/content/Context;[Ljava/lang/String;[Ljava/lang/String;Landroid/media/MediaScannerConnection$OnScanCompletedListener;)V

    new-instance v6, Ljava/lang/StringBuilder;

    invoke-direct {v6}, Ljava/lang/StringBuilder;-><init>()V

    const-string v4, "Saved: "

    invoke-virtual {v6, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v6, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v6}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v6

    invoke-static {v6}, Lcom/xzodomyx/Rec;->toast(Ljava/lang/String;)V

    goto :goto_ov

    :cond_fail
    const-string v6, "Recording stopped (nothing was captured)"

    invoke-static {v6}, Lcom/xzodomyx/Rec;->toast(Ljava/lang/String;)V

    :goto_ov
    # bring the REC button back now that capture is finished
    invoke-static {}, Lcom/xzodomyx/Hud;->showRec()V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method
