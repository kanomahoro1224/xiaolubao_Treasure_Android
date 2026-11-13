import 'package:flutter_test/flutter_test.dart';
import 'package:kafuno_music/features/kano/data/bilibili_api.dart';

/// 动态正文的表情解析。
///
/// 下面的 JSON 不是编的，是从 `x/polymer/web-dynamic/v1/feed/space` 的真实响应里
/// 抠出来的片段（2026-11 抓取）。B 站这套字段没有公开文档，写错一个名字不会报错，
/// 只会让正文里留下一串 `[鹿乃十周年动态_飞了]`，所以用真实结构锁住。
void main() {
  group('动态正文富文本', () {
    test('新版 opus 结构：EMOJI 节点解析出表情图', () {
      final json = {
        'modules': {
          'module_dynamic': {
            'major': {
              'opus': {
                'summary': {
                  'text': '大家好！[鹿乃十周年动态_飞了]',
                  'rich_text_nodes': [
                    {'type': 'RICH_TEXT_NODE_TYPE_TEXT', 'text': '大家好！'},
                    {
                      'type': 'RICH_TEXT_NODE_TYPE_EMOJI',
                      'text': '[鹿乃十周年动态_飞了]',
                      'icon_url': '',
                      'emoji': {
                        'type': '3',
                        'size': 2,
                        'text': '[鹿乃十周年动态_飞了]',
                        'icon_url':
                            'https://i0.hdslb.com/bfs/garb/1ea163e5a8e060c4b6c509e48b524d37e7c25f70.png',
                        'gif_url':
                            'https://i0.hdslb.com/bfs/garb/e020bf4c1eb60266ed7eeaaf2ffecac2f8e06384.gif',
                        'webp_url':
                            'https://i0.hdslb.com/bfs/garb/4578795a78a0ef028fa17e0058dce3d2bb92631c.webp',
                      },
                    },
                  ],
                },
              },
            },
          },
        },
      };

      final nodes = BiliDynamicApi.richNodesOf(json['modules']?['module_dynamic']);

      expect(nodes.length, 2);
      expect(nodes[0].isEmotion, isFalse);
      expect(nodes[0].text, '大家好！');
      expect(nodes[1].isEmotion, isTrue);
      // 图片在 emoji 下，不在节点顶层的 icon_url（那里是空串）。
      // 同一枚表情给了 gif / png / webp 三份，取动图那份 —— B 站原版是动的。
      expect(nodes[1].imageUrl, contains('i0.hdslb.com/bfs/garb/'));
      expect(nodes[1].imageUrl, endsWith('.gif'));
      // size 是数字 2，不是字符串
      expect(nodes[1].large, isTrue);
      // 图挂了时的兜底文案
      expect(nodes[1].text, '[鹿乃十周年动态_飞了]');
    });

    test('老结构：desc 里的 EMOTION 节点用 emoticon 字段', () {
      final json = {
        'desc': {
          'text': '测试[笑]',
          'rich_text_nodes': [
            {'type': 'RICH_TEXT_NODE_TYPE_TEXT', 'text': '测试'},
            {
              'type': 'RICH_TEXT_NODE_TYPE_EMOTION',
              'text': '[笑]',
              'emoticon': {
                'size': 1,
                'icon_url': 'https://i0.hdslb.com/bfs/emote/abc.png',
              },
            },
          ],
        },
      };

      final nodes = BiliDynamicApi.richNodesOf(json);

      expect(nodes.length, 2);
      expect(nodes[1].isEmotion, isTrue);
      expect(nodes[1].large, isFalse);
      expect(nodes[1].imageUrl, 'https://i0.hdslb.com/bfs/emote/abc.png');
    });

    test('拿不到表情图时退化成占位文字，不丢字', () {
      final json = {
        'desc': {
          'rich_text_nodes': [
            {'type': 'RICH_TEXT_NODE_TYPE_TEXT', 'text': '前'},
            {'type': 'RICH_TEXT_NODE_TYPE_EMOJI', 'text': '[破图]', 'emoji': {'size': 1}},
            {'type': 'RICH_TEXT_NODE_TYPE_TEXT', 'text': '后'},
          ],
        },
      };

      final nodes = BiliDynamicApi.richNodesOf(json);

      expect(nodes.map((n) => n.text).toList(), ['前', '[破图]', '后']);
      expect(nodes.every((n) => n.isEmotion), isFalse);
    });

    test('没有 rich_text_nodes 时返回空列表，交给调用方用纯文本', () {
      expect(BiliDynamicApi.richNodesOf({'desc': {'text': '纯文字'}}), isEmpty);
      expect(BiliDynamicApi.richNodesOf(null), isEmpty);
    });

    test('没有动图时回退静态首帧（小黄脸只有 icon_url）', () {
      final nodes = BiliDynamicApi.richNodesOf({
        'desc': {
          'rich_text_nodes': [
            {
              'type': 'RICH_TEXT_NODE_TYPE_EMOJI',
              'text': '[笑]',
              'emoji': {
                // 真实响应里缺动图是空串，不是没有这个 key
                'gif_url': '',
                'icon_url': 'https://i0.hdslb.com/bfs/garb/yellow.png',
                'webp_url': 'https://i0.hdslb.com/bfs/garb/yellow.webp',
                'size': 1,
              },
            },
          ],
        },
      });

      expect(nodes.single.imageUrl, 'https://i0.hdslb.com/bfs/garb/yellow.png');
    });

    test('协议相对的图片地址补成 https', () {
      final nodes = BiliDynamicApi.richNodesOf({
        'desc': {
          'rich_text_nodes': [
            {
              'type': 'RICH_TEXT_NODE_TYPE_EMOJI',
              'text': '[x]',
              'emoji': {
                'size': 1,
                'gif_url': '//i0.hdslb.com/bfs/emote/x.gif',
                'icon_url': '//i0.hdslb.com/bfs/emote/x.png',
              },
            },
          ],
        },
      });

      expect(nodes.single.imageUrl, 'https://i0.hdslb.com/bfs/emote/x.gif');
    });
  });
}
