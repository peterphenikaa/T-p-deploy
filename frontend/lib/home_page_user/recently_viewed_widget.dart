import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'recent_provider.dart';
import 'product_detail_page.dart';

class RecentlyViewedWidget extends StatelessWidget {
  const RecentlyViewedWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recent = Provider.of<RecentProvider>(context).recent;
    if (recent.isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Sản phẩm vừa xem',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            itemBuilder: (context, i) {
              final item = recent[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(
                      product: Map<String, dynamic>.from(item),
                    ),
                  ),
                ),
                child: Container(
                  width: 120,
                  margin: EdgeInsets.only(right: 10),
                  child: Card(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (item['image'] != null)
                          SizedBox(
                            height: 60,
                            child: Image.asset(
                              '${item['image']}',
                              fit: BoxFit.cover,
                            ),
                          ),
                        SizedBox(height: 6),
                        Text(
                          item['name'] ?? '',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
