import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zoo_home/content/content_cubit.dart';
import 'package:zoo_home/content/user_shelters/user_shelters_cubit.dart';
import 'package:zoo_home/content/user_shelters/user_shelters_state.dart';
import 'package:zoo_home/models/UserShelter.dart';
import 'package:zoo_home/widgets/user_shelter_card.dart';

class UserSheltersView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    bool isLoggedIn = context.read<ContentCubit>().isUserLoggedIn;
    return Scaffold(
      appBar: AppBar(
        title: Text('Зоодома'),
        centerTitle: true,
        actions: [
          if (!isLoggedIn)
            OneTapTooltip(
              message:
                  'Нажмите на кнопку справа, если хотите войти и создать свой Зоодом. Требуется авторизация',
              child: Icon(Icons.info_outline),
            ),
          IconButton(
            icon: Icon(isLoggedIn ? Icons.home : Icons.login),
            onPressed: () => isLoggedIn
                ? context.read<ContentCubit>().showProfile()
                : context.read<ContentCubit>().showAuth(),
          ),
        ],
      ),
      body: BlocBuilder<UserSheltersCubit, UserSheltersState>(
          builder: (context, state) {
        if (state is ListUserSheltersSuccess) {
          return state.userShelters.isEmpty
              ? _emptyUserSheltersView()
              : _userSheltersListView(state.userShelters, state.avatarsKeyUrl);
        } else if (state is ListUserSheltersFailure) {
          return _exceptionView(state.exception);
        } else {
          return Container(
            color: Colors.white,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      }),
    );
  }

  Widget _exceptionView(Exception exception) {
    return Center(child: Text(exception.toString()));
  }

  Widget _emptyUserSheltersView() {
    return Center(
      child: Text('Еще не создано ни одного зоодома'),
    );
  }

  Widget _userSheltersListView(
      List<UserShelter> userShelters, Map<String, String> avatarsKeyUrl) {
    return ListView.builder(
      itemCount: userShelters.length,
      itemBuilder: (BuildContext context, int index) {
        final userShelter = userShelters[index];
        return UserShelterCard(
            onTap: () => context
                .read<ContentCubit>()
                .showProfile(selectedUser: userShelter),
            userShelter: userShelter,
            avatarUrl: avatarsKeyUrl.containsKey(userShelter.avatarKey)
                ? avatarsKeyUrl[userShelter.avatarKey]
                : null);
      },
    );
  }
}

class OneTapTooltip extends StatelessWidget {
  final Widget child;
  final String message;

  OneTapTooltip({@required this.message, @required this.child});

  @override
  Widget build(BuildContext context) {
    final key = GlobalKey<State<Tooltip>>();
    return Tooltip(
      key: key,
      message: message,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(key),
        child: child,
      ),
      height: 50,
    );
  }

  void _onTap(GlobalKey key) {
    final dynamic tooltip = key.currentState;
    tooltip?.ensureTooltipVisible();
  }
}
