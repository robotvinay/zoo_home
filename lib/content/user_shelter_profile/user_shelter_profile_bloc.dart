import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_absolute_path/flutter_absolute_path.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_image_picker2/multi_image_picker2.dart';
import 'package:zoo_home/auth/form_submission_status.dart';
import 'package:zoo_home/models/UserShelter.dart';
import 'package:zoo_home/content/user_shelter_profile/user_shelter_profile_event.dart';
import 'package:zoo_home/content/user_shelter_profile/user_shelter_profile_state.dart';
import 'package:zoo_home/content/user_shelters/user_shelter_repository.dart';
import 'package:zoo_home/repositories/storage_repository.dart';
import 'package:zoo_home/services/image_url_cache.dart';

class UserShelterProfileBloc
    extends Bloc<UserShelterProfileEvent, UserShelterProfileState> {
  final UserShelterRepository userShelterRepo;
  final StorageRepository storageRepo;
  final _imagePicker = ImagePicker();

  UserShelterProfileBloc({
    @required this.userShelterRepo,
    @required this.storageRepo,
    @required UserShelter user,
    @required bool isCurrentUser,
  }) : super(
            UserShelterProfileState(user: user, isCurrentUser: isCurrentUser)) {
    ImageUrlCache.instance
        .getUrl(user.avatarKey)
        .then((url) => add(ProvideAvatarImagePath(avatarUrl: url)));
    Future.wait(user.images.map((imageKey) async {
      return await ImageUrlCache.instance.getUrl(imageKey);
    }).toList())
        .then((urls) => add(ProvideProfileImagesPaths(imageUrls: urls)));
  }

  @override
  Stream<UserShelterProfileState> mapEventToState(
      UserShelterProfileEvent event) async* {
    if (event is ChangeAvatarRequest) {
      yield state.copyWith(avatarImageSourceActionSheetIsVisible: true);
    } else if (event is OpenImagePicker) {
      yield state.copyWith(avatarImageSourceActionSheetIsVisible: false);

      final pickedImage =
          await _imagePicker.getImage(source: event.imageSource);
      if (pickedImage == null) return;

      final imageKey =
          await storageRepo.uploadFile(File(pickedImage.path), state.user.id);
      final updatedUser = state.user.copyWith(avatarKey: imageKey);

      final results = await Future.wait([
        userShelterRepo.updateUser(updatedUser),
        storageRepo.getUrlForFile(imageKey),
      ]);

      yield state.copyWith(user: updatedUser, avatarUrl: results.last);
    } else if (event is ProvideAvatarImagePath) {
      yield state.copyWith(avatarUrl: event.avatarUrl);
    } else if (event is OpenMultiImagePicker) {
      List<Asset> pickedImages = <Asset>[];
      try {
        pickedImages = await MultiImagePicker.pickImages(
          maxImages: 8,
          enableCamera: false,
          cupertinoOptions: CupertinoOptions(
            takePhotoIcon: "chat",
            doneButtonTitle: "Fatto",
          ),
          materialOptions: MaterialOptions(
            actionBarColor: "#abcdef",
            actionBarTitle: "Галерея зоодома",
            allViewTitle: "Все изображения",
            useDetailsView: false,
            selectCircleStrokeColor: "#000000",
          ),
        );
      } on Exception catch (e) {
        print(e.toString());
      }
      if (pickedImages == null || pickedImages.isEmpty) return;

      final imagesKeys = await Future.wait(pickedImages.map((image) async {
        final imagePath =
            await FlutterAbsolutePath.getAbsolutePath(image.identifier);
        return await storageRepo.uploadFile(File(imagePath), state.user.id);
      }).toList());

      final imageUrls = await Future.wait(imagesKeys.map((imageKey) async {
        return await storageRepo.getUrlForFile(imageKey);
      }).toList());

      final updatedUser = state.user.copyWith(images: imagesKeys);
      await userShelterRepo.updateUser(updatedUser);

      yield state.copyWith(user: updatedUser, imageUrls: imageUrls);
    } else if (event is ProvideProfileImagesPaths) {
      yield state.copyWith(imageUrls: event.imageUrls);
    } else if (event is UserShelterProfileLocationChanged) {
      yield state.copyWith(location: event.location);
    } else if (event is UserShelterProfileTitleChanged) {
      yield state.copyWith(title: event.title);
    } else if (event is UserShelterProfileDescriptionChanged) {
      yield state.copyWith(description: event.description);
    } else if (event is SaveUserShelterProfileChanges) {
      yield state.copyWith(formStatus: FormSubmitting());

      final updatedUser = state.user.copyWith(
        location: state.location,
        title: state.title,
        description: state.description,
      );

      try {
        await userShelterRepo.updateUser(updatedUser);
        yield state.copyWith(
            user: updatedUser, formStatus: SubmissionSuccess());
      } catch (e) {
        yield state.copyWith(formStatus: SubmissionFailed(e));
      }
    }
  }
}
