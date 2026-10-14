#
# OPPO K10x 5G (PGGM10 / OP5295) —— OrangeFox 产品注册
#
# 这个文件告诉 build 系统「本设备树提供哪些 product」。
# lunch 的时候能看到的就是下面 COMMON_LUNCH_CHOICES 里的项。
#
# ★关于 lunch 组合的格式（实测踩过的坑）★
#
#   A13 / A14 的 lunch 组合是【三段式】：
#       <product>-<release>-<variant>   例如 fox_PGGM10-trunk_staging-eng
#   A12 及以下才是【两段式】：
#       <product>-<variant>             例如 fox_PGGM10-eng
#
#   实测报错（A14 源码树 + 两段式）：
#       Invalid lunch combo: fox_PGGM10-eng
#       Valid combos must be of the form <product>-<release>-<variant>
#   依据：envsetup.sh 里判据是 [[ "$combo" != *-*-* ]]，
#         即「必须含两个 '-'」，两段式只有 0 个或 1 个，直接判非法。
#
#   ★同时列上两种格式是安全的★
#     COMMON_LUNCH_CHOICES 只是被 product_config.mk 收集，
#     它【不做】格式校验；格式校验只发生在你手动 lunch 的那一刻。
#     所以两段式条目在 A14 上只是「不能被直接 lunch」，
#     不会让 make / 构建失败（已用 GNU make 实测：混合列出 PARSE OK）。
#
#   工作流那侧还会自动从 `lunch` 输出的合法组合里挑，
#   所以即使 release 段不是 trunk_staging 也能兜住。
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/fox_PGGM10.mk

COMMON_LUNCH_CHOICES := \
    fox_PGGM10-trunk_staging-eng \
    fox_PGGM10-trunk_staging-userdebug \
    fox_PGGM10-trunk_staging-user \
    fox_PGGM10-eng \
    fox_PGGM10-userdebug \
    fox_PGGM10-user
