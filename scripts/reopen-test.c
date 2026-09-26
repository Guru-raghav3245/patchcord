// Diagnostic: does the device survive open -> close -> reopen in one process?
// cc -arch arm64 -Ivendor/prefix/include -Lvendor/prefix/lib -lmtp scripts/reopen-test.c -o /tmp/reopen-test
#include <libmtp.h>
#include <stdio.h>
#include <unistd.h>
int main(void) {
  LIBMTP_Init();
  for (int i = 1; i <= 3; i++) {
    LIBMTP_raw_device_t *raw; int n;
    if (LIBMTP_Detect_Raw_Devices(&raw, &n) || n < 1) { printf("attempt %d: no device\n", i); return 1; }
    LIBMTP_mtpdevice_t *d = LIBMTP_Open_Raw_Device_Uncached(raw);
    printf("attempt %d: open %s\n", i, d ? "OK" : "FAILED");
    if (!d) return 1;
    LIBMTP_Release_Device(d);
    printf("attempt %d: released\n", i);
    sleep(2);
  }
  return 0;
}
