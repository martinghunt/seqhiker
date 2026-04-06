#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libzem.h"

static void fail(const char *msg) {
	fprintf(stderr, "%s\n", msg);
	exit(1);
}

static char *decode_wire_text(const uint8_t *data, uint32_t len) {
	if (data == NULL || len < 2) {
		fail("payload too short");
	}
	uint16_t text_len = (uint16_t)data[0] | ((uint16_t)data[1] << 8);
	if ((uint32_t)text_len + 2 > len) {
		fail("malformed wire text payload");
	}
	char *out = (char *)malloc((size_t)text_len + 1);
	if (out == NULL) {
		fail("malloc failed");
	}
	memcpy(out, data + 2, text_len);
	out[text_len] = '\0';
	return out;
}

int main(void) {
	uint64_t backend = ZemBackendCreate();
	if (backend == 0) {
		fail("failed to create backend");
	}

	ZemResponse version = ZemBackendHandleRequest(backend, 19, NULL, 0);
	if (version.message_type != 19) {
		fail("unexpected version response type");
	}
	char *version_text = decode_wire_text(version.data, version.len);
	printf("version=%s\n", version_text);
	free(version_text);
	ZemResponseFree(version.data);

	uint8_t invalid_pair_payload[2] = {0xff, 0xff};
	ZemResponse invalid = ZemBackendHandleRequest(backend, 24, invalid_pair_payload, 2);
	if (invalid.message_type != 8) {
		fail("expected MsgError for invalid comparison block request");
	}
	char *error_text = decode_wire_text(invalid.data, invalid.len);
	printf("error=%s\n", error_text);
	free(error_text);
	ZemResponseFree(invalid.data);

	ZemBackendFree(backend);
	return 0;
}
