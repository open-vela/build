ifneq ($(filter goldfish64_%, $(TARGET_DEVICE)),)
PRODUCT_COPY_FILES += \
    vendor/vela/build/android/public.libraries-xiaomi.txt:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/public.libraries-xiaomi.txt
endif

PRODUCT_BOOT_JARS += cpc-extension

PRODUCT_PACKAGES += \
    kvget \
    kvset \
    rexec \
    rpsock_client \
    rpsock_server \
    TestServerCpc \
    TestClientCpc \
    cpc-extension \
    libcpc_extension_jni.xiaomi

# enable audio hidl hal 7.1
PRODUCT_PACKAGES += android.hardware.audio@7.1-impl

# enable audio hidl hal 7.1 for vela
PRODUCT_PACKAGES += android.hardware.audio@7.1-impl.vela

PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST += \
    system/bin/kvget \
    system/bin/kvset \
    system/bin/rexec \
    system/bin/rpsock_client \
    system/bin/rpsock_server \
    system/bin/TestServerCpc \
    system/bin/TestClientCpc \
    system/framework/cpc-extension.jar \
    system/lib64/libcpc_extension_jni.xiaomi.so \
    system/etc/permissions/cpc-extension.xml

## Add vela audio HAL sepolicy
BOARD_SEPOLICY_DIRS += vendor/vela/hardware/audio/sepolicy/

## Sensor hal
PRODUCT_COPY_FILES += \
    vendor/vela/build/android/etc/ueventd.vela.rc:$(TARGET_COPY_OUT_ODM)/etc/ueventd.vela.rc

# Sensor HAL
-include vendor/vela/hardware/sensor/sensors.mk

# GNSS HAL
-include vendor/vela/hardware/gnss/gnss.mk

-include vendor/vela/build/android/$(TARGET_PRODUCT).mk

## Vela Bluetooh
-include vendor/vela/hardware/bluetooth/system_bt.mk
