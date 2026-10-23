# 《钛虎帝博》广告首稿

- 状态：用户已批准，已生成 128×192 运行纹理并加入游戏轮播白名单
- 工作流：Codex 内置 `image_gen`，单图编辑（identity-preserve）
- 原图：`广告原图/微信图片_20261023105513_75_13.jpg`
- 输出：`candidate.png`

## 最终生成提示词

Use case: identity-preserve edit for a fictional in-world movie billboard advertisement.

Image 1 is the edit target.

Scene and composition:
Preserve the original portrait canvas, the iconic low-angle ceremonial presentation composition, the upward-held mascot pose, the supporting forearm and hand, the warm sunrise/sunset backlight, the subject scale, head angle, and the bottom title zone. Keep the dramatic heroic silhouette and centered vertical poster balance.

Human face — hard invariant:
Preserve the adult man's face from Image 1 as faithfully as possible: same recognizable facial identity, facial structure, expression, gaze, skin tone, head angle, hairline, and photographic realism. The face must remain fully human and must not become robotic, feline, masked, or stylized beyond matching the poster lighting.

Specified transformation:
Change only the furry animal body into a compact mechanical big-cat mascot body. It should read as a cute but imposing titanium feline mascot: layered brushed-metal armor plates, articulated feline shoulders and paws, subtle mechanical joints, compact cub-like proportions, a small segmented tail if naturally visible, and restrained cyan plus amber emitter lights. No exposed weapons. Blend the preserved human head naturally into the mechanical feline neck assembly. Keep the original limb count and pose; the supporting hand must still grip and lift the body naturally.

World and visual treatment:
Fictional cyberpunk cinema poster, premium but slightly pulpy. Warm amber sunlight against cool cyan mechanical accents, chunky readable shapes suitable for later display on a low-resolution outdoor LED wall, controlled contrast, minimal fine-detail noise. The sky may hint at a distant futuristic megacity silhouette, but do not add extra people, creatures, vehicles, or props.

Text:
Remove all original English title text and all other original copy. Render exactly these four Chinese characters, verbatim and in this order: "钛虎帝博". Make them the only text in the image, large at the bottom, centered, highly legible, with bold cinematic gold Chinese title lettering. No subtitle. No English. No extra characters.

Hard constraints:
No real brands, studio marks, trademarks, copyrighted character designs, platform UI, watermarks, signatures, or logos. Do not crop the face, paws, supporting hand, or title. Do not add extra limbs, fingers, characters, or objects. Preserve the original portrait aspect ratio rather than forcing 16:9. This is one single finished poster image, not a mockup in a frame.
