import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NoConnectionBox extends StatelessWidget {
  final VoidCallback onRetry;
  const NoConnectionBox({Key? key, required this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxWidth = size.width * 0.85;
    final boxHeight = size.height * 0.66;

    return Center(
      child: Container(
        width: boxWidth,
        height: boxHeight,
        padding: EdgeInsets.all(size.width * 0.04),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: Offset(2, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo_connection_out.png',
              width: size.width * 0.15,
              height: size.width * 0.15,
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.welcome,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.noConnectionMessage,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}