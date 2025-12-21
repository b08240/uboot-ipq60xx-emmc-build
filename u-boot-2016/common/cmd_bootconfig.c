/*
 * Copyright (c) 2018, The Linux Foundation. All rights reserved.

 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 and
 * only version 2 as published by the Free Software Foundation.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#include <common.h>
#include <command.h>
#include <asm/arch-qca-common/smem.h>
#include <part.h>
#include <mmc.h>
#include <sdhci.h>
#include <mapmem.h>

#ifndef CONFIG_SDHCI_SUPPORT
extern qca_mmc mmc_host;
#else
extern struct sdhci_host mmc_host;
#endif

#define BOOT_PART_PRIMARY      0x0
#define BOOT_PART_SECONDARY    0x1
#define WRITE_SIZE_IN_BYTES	   1
#define LOAD_RAM_ADDR          0x50000000
#define BOOTCONFIG_PART_NUM	   2
#define BOOTCONFIG_OFFSET_NUM  3

static int do_bootconfig(cmd_tbl_t *cmdtp, int flag, int argc, char * const argv[]) {
	void *start;
    u8 *bootconfig_flag;
	char buf[66];
	int ret = CMD_RET_SUCCESS;
	int changed, boot_part;
	uint32_t offset = 0, part_size = 0;
    block_dev_desc_t *blk_dev;
    disk_partition_t disk_info = {0};
	qca_smem_flash_info_t *sfi = &qca_smem_flash_info;
	char* bootconfig_part_name[BOOTCONFIG_PART_NUM] = {"0:BOOTCONFIG", "0:BOOTCONFIG1"};
	ulong bootconfig_offset[BOOTCONFIG_OFFSET_NUM] = {0x80, 0x94, 0xA8};

	if (argc != 3)
		return CMD_RET_USAGE;

	if (strcmp(argv[1], "set") != 0)
		return CMD_RET_USAGE;

	if (strcmp(argv[2], "primary") == 0)
		boot_part = BOOT_PART_PRIMARY;
	else if (strcmp(argv[2], "secondary") == 0)
		boot_part = BOOT_PART_SECONDARY;
	else
		return CMD_RET_USAGE;

	if (sfi->flash_type == SMEM_BOOT_MMC_FLASH) {
		for (int part_index = 0; part_index < BOOTCONFIG_PART_NUM; part_index++) {
			blk_dev = mmc_get_dev(mmc_host.dev_num);
            if (blk_dev == NULL)
                return CMD_RET_FAILURE;
            ret = get_partition_info_efi_by_name(blk_dev, bootconfig_part_name[part_index], &disk_info);
            if (ret) {
                printf("\nPartition %s not found, skipping...\n", bootconfig_part_name[part_index]);
                ret = CMD_RET_SUCCESS;
                continue;
            }
            offset = (ulong)disk_info.start;
            part_size = (ulong)disk_info.size;

			sprintf(buf,
				"mmc read 0x%lx 0x%lx 0x%lx",
				(unsigned long int)LOAD_RAM_ADDR,
				(unsigned long int)offset,
				(unsigned long int)part_size);
			ret = run_command(buf, 0);
			if (ret)
				continue;

			changed = 0;
			start = map_sysmem(LOAD_RAM_ADDR, WRITE_SIZE_IN_BYTES);
			for (int offset_index = 0; offset_index < BOOTCONFIG_OFFSET_NUM; offset_index++) {
                bootconfig_flag = (u8 *)(start + bootconfig_offset[offset_index]);
				if (*bootconfig_flag != (u8)boot_part) {
                    *bootconfig_flag = (u8)boot_part;
					changed = 1;
				}
			}
			if (changed) {
				sprintf(buf,
					"flash %s 0x%lx 0x%lx",
					bootconfig_part_name[part_index],
					(unsigned long int)LOAD_RAM_ADDR,
					(unsigned long int)(part_size * disk_info.blksz));
				ret = run_command(buf, 0);
			}
			unmap_sysmem(start);
		}
		if (!ret) {
			printf("\nBOOTCONFIG setup completed!\n");
		}
	} else {
		printf("NOT supported BOOT FLASH Type!\n");
		ret = CMD_RET_FAILURE;
	}

	return ret;
}

U_BOOT_CMD(
	bootconfig, 3, 0, do_bootconfig,
	"bootconfig set [primary/secondary]",
	"set bootconfig info in 0:BOOTCONFIG and 0:BOOTCONFIG1\n"
);
