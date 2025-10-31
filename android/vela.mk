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

# display offload

PRODUCT_SYSTEM_SERVER_JARS_EXTRA += \
    system_ext:displayoffload-services

PRODUCT_PACKAGES += \
    displayoffload-services \
    MiDisplayOffload

PRODUCT_SYSTEM_EXT_PROPERTIES += config.enable_display_offload=true
TARGET_FS_CONFIG_GEN += vendor/vela/frameworks/graphics/displayoffload/android/config/offload.fs
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += vendor/vela/frameworks/graphics/displayoffload/android/sepolicy

# display offload end
