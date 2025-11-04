ifneq ($(filter goldfish64_%, $(TARGET_DEVICE)),)
PRODUCT_COPY_FILES += \
    vendor/vela/build/android/public.libraries-xiaomi.txt:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/public.libraries-xiaomi.txt
endif

PRODUCT_BOOT_JARS += cpc-extension

PRODUCT_PACKAGES += \
    kvget \
    kvset \
    rpsock_client \
    rpsock_server \
    TestServerCpc \
    TestClientCpc \
    cpc-extension \
    libcpc_extension_jni.xiaomi

PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST += \
    system/bin/kvget \
    system/bin/kvset \
    system/bin/rpsock_client \
    system/bin/rpsock_server \
    system/bin/TestServerCpc \
    system/bin/TestClientCpc \
    system/framework/cpc-extension.jar \
    system/lib64/libcpc_extension_jni.xiaomi.so \
    system/etc/permissions/cpc-extension.xml

-include vendor/vela/build/android/$(TARGET_PRODUCT).mk
