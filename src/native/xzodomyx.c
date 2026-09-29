/*
 * libxzodomyx.so -- armeabi-v7a native probe for MCPE 0.14.3.
 *
 * PURPOSE AND SCOPE
 * -----------------
 * This is deliberately NOT a game hook. It exists to (a) prove the native build
 * path in this environment end-to-end and (b) give a zero-risk, on-device way to
 * validate the assumptions Features 4/5/6 would depend on, BEFORE anyone writes
 * code that runs inside the game's process every frame.
 *
 * It is NOT bundled into the shipped APK. See docs/03-FEATURES-3-6-FEASIBILITY.md.
 *
 * NO NDK HEADERS
 * --------------
 * There is no Android sysroot here, so libc/JNI declarations are written out by
 * hand. Only dlopen/dlsym are referenced; on API 21 the linker namespace is
 * global, so those resolve from libdl without a DT_NEEDED entry. Nothing else
 * from libc is touched, which is why this builds -nostdlib cleanly.
 */

#define RTLD_NOW 0x00000002

extern void *dlopen(const char *filename, int flag);
extern void *dlsym(void *handle, const char *symbol);
extern int dlclose(void *handle);

/* The exported symbols Feature 4 would need. All confirmed present in the
 * 0.14.3 dynamic symbol table (19,561 GLOBAL FUNCs, not stripped). */
static const char *const kFeature4Symbols[] = {
    "_ZN16MoveInputHandler17_updateMoveVectorEff",
    "_ZN16MoveInputHandler17_updateButtonDownEPbb",
    "_ZN16MoveInputHandler12_toggleSneakEv",
    "_ZN16MoveInputHandler15clearInputStateEv",
    "_ZN16MoveInputHandler18clearMovementStateEv",
    "_ZN11LocalPlayer11setSneakingEb",
    /* the instance problem: only the ctor is exported, there is no accessor */
    "_ZN16MoveInputHandlerC1ER12InputHandlerRK7Options",
    0};

static const char *const kFeature6Symbols[] = {
    "_ZN9Minecraft19getNetEventCallbackEv",
    "_ZN9Minecraft15getPacketSenderEv",
    0};

/*
 * Returns a bitmask of which probed symbols resolved.
 * Bit i == 1 means kFeature4Symbols[i] was found.
 *
 * Pure read-only introspection: it resolves addresses and returns. It never
 * calls into the engine, never writes memory, and never installs a hook --
 * so it cannot perturb gameplay.
 */
__attribute__((visibility("default")))
int xzo_probe(void)
{
    void *h = dlopen("libminecraftpe.so", RTLD_NOW);
    if (!h)
        return -1;

    int mask = 0;
    int i;
    for (i = 0; kFeature4Symbols[i] && i < 31; i++) {
        if (dlsym(h, kFeature4Symbols[i]))
            mask |= (1 << i);
    }
    for (i = 0; kFeature6Symbols[i] && i < 8; i++) {
        if (dlsym(h, kFeature6Symbols[i]))
            mask |= (1 << (24 + i));
    }
    dlclose(h);
    return mask;
}

/* JNI_OnLoad without jni.h: the VM only needs the returned version constant.
 * Returning a constant is the entire body, so loading this library cannot fail
 * at runtime for any reason other than the ELF itself being unloadable. */
#define JNI_VERSION_1_6 0x00010006

__attribute__((visibility("default")))
int JNI_OnLoad(void *vm, void *reserved)
{
    (void)vm;
    (void)reserved;
    return JNI_VERSION_1_6;
}
