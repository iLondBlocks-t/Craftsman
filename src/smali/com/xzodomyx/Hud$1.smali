.class Lcom/xzodomyx/Hud$1;
.super Ljava/lang/Object;
.source "Hud.java"

# Defers showing the REC button until the decor view actually has a window token.
# Calling showAtLocation() straight from onResume can throw BadTokenException.

.implements Ljava/lang/Runnable;


# direct methods
.method constructor <init>()V
    .locals 0

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method


# virtual methods
.method public run()V
    .locals 1

    :try_start_0
    invoke-static {}, Lcom/xzodomyx/Hud;->showRec()V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method
