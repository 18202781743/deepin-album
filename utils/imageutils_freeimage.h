/*
 * Copyright (C) 2016 ~ 2018 Deepin Technology Co., Ltd.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include "baseutils.h"
#include <FreeImage.h>
#include <QDateTime>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QMap>
#include <QString>
#include <QDebug>
#include <QObject>
#include <QMimeDatabase>
#include <QMimeType>
#include <QMutex>

#include <QThread>

static QMutex freeimage_mutex;

namespace utils {

namespace image {

namespace freeimage {

FREE_IMAGE_FORMAT fFormat(const QString &path)
{
    const QByteArray ba = path.toUtf8();
    const char *pc = ba.data();
    FREE_IMAGE_FORMAT fif = FIF_UNKNOWN;
    fif = FreeImage_GetFileType(pc, 0);
    if (fif == FIF_UNKNOWN) {
        fif = FreeImage_GetFIFFromFilename(pc);
    }
    return fif;
}

const QString getFileFormat(const QString &path)
{
#if 0
    const FREE_IMAGE_FORMAT fif = fFormat(path);
    if (fif == FIF_UNKNOWN) {
        return QString("UNKNOW");
    } else {
        return QString(FreeImage_GetFIFMimeType(fif));
    }
#endif
    //use mimedatabase get image mimetype
    QFileInfo fi(path);
    QString suffix = fi.suffix();
    return suffix;
    QMimeDatabase db;
    QMimeType mt = db.mimeTypeForFile(path, QMimeDatabase::MatchContent);
    QMimeType mt1 = db.mimeTypeForFile(path, QMimeDatabase::MatchExtension);
    if (suffix.isEmpty()) {
        return mt.name();
    } else {
        return mt1.name();
    }
}

FIBITMAP *readFileToFIBITMAP(const QString &path, int flags FI_DEFAULT(0))
{
    const FREE_IMAGE_FORMAT fif = fFormat(path);
    if ((fif != FIF_UNKNOWN) && FreeImage_FIFSupportsReading(fif)) {
        const QByteArray ba = path.toUtf8();
        const char *pc = ba.data();
        FIBITMAP *dib = FreeImage_Load(fif, pc, flags);
        return dib;
    }
    return nullptr;
}

QMap<QString, QString> getMetaData(FREE_IMAGE_MDMODEL model, FIBITMAP *dib)
{
    QMap<QString, QString> mdMap;  // key-data
    FITAG *tag = nullptr;
    FIMETADATA *mdhandle = nullptr;
    mdhandle = FreeImage_FindFirstMetadata(model, dib, &tag);
    if (mdhandle) {
        do {
            mdMap.insert(FreeImage_GetTagKey(tag),
                         FreeImage_TagToString(model, tag));
        } while (FreeImage_FindNextMetadata(mdhandle, &tag));
        FreeImage_FindCloseMetadata(mdhandle);
    }
    return mdMap;
}

const QDateTime getDateTime(const QString &path, bool createTime = true)
{
    FIBITMAP *dib = readFileToFIBITMAP(path, FIF_LOAD_NOPIXELS);
    auto datas = getMetaData(FIMD_EXIF_EXIF, dib);
    if (datas.isEmpty()) {
        QFileInfo info(path);
        if (createTime) {
            return info.created();
        } else {
            return info.lastModified();
        }
    }
    if (createTime) {
        return utils::base::stringToDateTime(datas["DateTimeOriginal"]);
    } else {
        return utils::base::stringToDateTime(datas["DateTimeDigitized"]);
    }
}

const QString getOrientation(const QString &path)
{
    FIBITMAP *dib = readFileToFIBITMAP(path, FIF_LOAD_NOPIXELS);
    auto datas = getMetaData(FIMD_EXIF_MAIN, dib);
    if (datas.isEmpty()) {
        return QString();
    }
    return datas["Orientation"];
}

QString DateToString(QDateTime ot)
{
    QStringList datelist;
    datelist.append(QString::number(ot.date().year()));
    datelist.append(QString::number(ot.date().month()));
    datelist.append(QString::number(ot.date().day()));
    return QString(QObject::tr("%1/%2/%3")).arg(datelist[0]).arg(datelist[1]).arg(datelist[2]) + " " + ot.toString("hh:MM") ;
}

/*!
 * \brief getAllMetaData
 * This function is very fast with FIF_LOAD_NOPIXELS flag
 * \param path
 * \return
 */
QMap<QString, QString> getAllMetaData(const QString &path)
{
    QMutexLocker mutex(&freeimage_mutex);

    //qDebug() << "threadid:" << QThread::currentThread() << "getAllMetaData locking ....";

    FIBITMAP *dib = readFileToFIBITMAP(path, FIF_LOAD_NOPIXELS);
    QMap<QString, QString> admMap;
    admMap.unite(getMetaData(FIMD_EXIF_MAIN, dib));
    admMap.unite(getMetaData(FIMD_EXIF_EXIF, dib));
    admMap.unite(getMetaData(FIMD_EXIF_GPS, dib));
    admMap.unite(getMetaData(FIMD_EXIF_MAKERNOTE, dib));
    admMap.unite(getMetaData(FIMD_EXIF_INTEROP, dib));
    admMap.unite(getMetaData(FIMD_IPTC, dib));
    // Basic extended data
    QFileInfo info(path);
    if (admMap.isEmpty()) {
        QDateTime emptyTime(QDate(0, 0, 0), QTime(0, 0, 0));
        admMap.insert("DateTimeOriginal",  emptyTime.toString("yyyy/MM/dd HH:mm:dd"));
        admMap.insert("DateTimeDigitized", info.lastModified().toString("yyyy/MM/dd HH:mm:dd"));
    } else {
        // ReFormat the date-time
        using namespace utils::base;
        // Exif version 0231
        QString qsdto = admMap.value("DateTimeOriginal");
        QString qsdtd = admMap.value("DateTimeDigitized");
        QDateTime ot = stringToDateTime(qsdto);
        QDateTime dt = stringToDateTime(qsdtd);
        if (! ot.isValid()) {
            // Exif version 0221
            QString qsdt = admMap.value("DateTime");
            ot = stringToDateTime(qsdt);
            dt = ot;

            // NO valid date information
            if (! ot.isValid()) {
                admMap.insert("DateTimeOriginal", info.created().toString("yyyy/MM/dd HH:mm:dd"));
                admMap.insert("DateTimeDigitized", info.lastModified().toString("yyyy/MM/dd HH:mm:dd"));
            }
        }
        admMap.insert("DateTimeOriginal", ot.toString("yyyy/MM/dd HH:mm:dd"));
        admMap.insert("DateTimeDigitized", dt.toString("yyyy/MM/dd HH:mm:dd"));

    }

//    // The value of width and height might incorrect
    QImageReader reader(path);
    int w = reader.size().width();
    w = w > 0 ? w : FreeImage_GetWidth(dib);
    int h = reader.size().height();
    h = h > 0 ? h : FreeImage_GetHeight(dib);
    admMap.insert("Dimension", QString::number(w) + "x" + QString::number(h));

    admMap.insert("FileName", info.fileName());
    admMap.insert("FileFormat", getFileFormat(path));
    admMap.insert("FileSize", utils::base::sizeToHuman(info.size()));
    FreeImage_Unload(dib);
    //qDebug() <<  QThread::currentThread() << "getAllMetaData lock end";
    return admMap;
}

FIBITMAP *makeThumbnail(const QString &path, int size)
{
    const QByteArray pb = path.toUtf8();
    const char *pc = pb.data();
    FIBITMAP *dib = nullptr;
    int flags = 0;              // default load flag
    FREE_IMAGE_FORMAT fif = fFormat(path);
    if (fif == FIF_UNKNOWN) {
        return nullptr;
    }
    // for JPEG images, we can speedup the loading part
    // Using LibJPEG downsampling feature while loading the image...
    if (fif == FIF_JPEG) {
        flags = JPEG_EXIFROTATE;
        flags |= size << 16;
        // Load the dib
        dib = FreeImage_Load(fif, pc, flags);
        if (! dib) return nullptr;
    } else {
        // Any cases other than the JPEG case: load the dib ...
        if (fif == FIF_RAW || fif == FIF_TIFF) {
            // ... except for RAW images, try to load the embedded JPEG preview
            // or default to RGB 24-bit ...
            flags = RAW_PREVIEW;
            dib = FreeImage_Load(fif, pc, flags);
            if (!dib) return nullptr;
        } else {
            return nullptr;
        }
    }
    // create the requested thumbnail
    FIBITMAP *thumbnail = FreeImage_MakeThumbnail(dib, size, TRUE);
    FreeImage_Unload(dib);
    return thumbnail;
}

bool isSupportsReading(const QString &path)
{
    const FREE_IMAGE_FORMAT fif = fFormat(path);
    return (fif != FIF_UNKNOWN) && FreeImage_FIFSupportsReading(fif);
}

bool isSupportsWriting(const QString &path)
{
    FREE_IMAGE_FORMAT fif = fFormat(path);
    return (fif != FIF_UNKNOWN) && FreeImage_FIFSupportsWriting(fif);
}

bool canSave(FIBITMAP *dib, const QString &path)
{
    FREE_IMAGE_FORMAT fif = FIF_UNKNOWN;
    // Try to guess the file format from the file extension
    fif = FreeImage_GetFIFFromFilename(path.toUtf8().data());
    if (fif != FIF_UNKNOWN) {
        // Check that the dib can be saved in this format
        BOOL bCanSave;
        FREE_IMAGE_TYPE image_type = FreeImage_GetImageType(dib);
        qDebug() << "image_type:" << image_type << endl;
        if (image_type == FIT_BITMAP) {
            // standard bitmap type
            // check that the plugin has sufficient writing
            // and export capabilities ...
            WORD bpp = static_cast<WORD>(FreeImage_GetBPP(dib));
            bCanSave = (FreeImage_FIFSupportsWriting(fif) &&
                        FreeImage_FIFSupportsExportBPP(fif, bpp));
        } else {
            // special bitmap type
            // check that the plugin has sufficient export capabilities
            bCanSave = FreeImage_FIFSupportsExportType(fif, image_type);
        }
        return bCanSave;
    }
    return false;
}

bool canSave(const QString &path)
{
    FIBITMAP *dib = readFileToFIBITMAP(path, FIF_LOAD_NOPIXELS);
    bool v = canSave(dib, path);
    FreeImage_Unload(dib);
    return v;
}

bool writeFIBITMAPToFile(FIBITMAP *dib, const QString &path, int flag = 0)
{
    FREE_IMAGE_FORMAT fif = FIF_UNKNOWN;
    BOOL bSuccess = FALSE;
    const QByteArray ba = path.toUtf8();
    const char *pc = ba.data();
    // Try to guess the file format from the file extension
    fif = FreeImage_GetFIFFromFilename(pc);
    if (fif != FIF_UNKNOWN && canSave(dib, path)) {
        bSuccess = FreeImage_Save(fif, dib, pc, flag);
    }
    return (bSuccess == TRUE) ? true : false;
}

QImage noneQImage()
{
    static QImage none(0, 0, QImage::Format_Invalid);
    return none;
}

bool isNoneQImage(const QImage &qi)
{
    return qi == noneQImage();
}

QImage FIBitmapToQImage(FIBITMAP *dib)
{
    if (!dib || FreeImage_GetImageType(dib) != FIT_BITMAP)
        return noneQImage();
    int width  = FreeImage_GetWidth(dib);
    int height = FreeImage_GetHeight(dib);
    switch (FreeImage_GetBPP(dib)) {
    case 1: {
        QImage result(width, height, QImage::Format_Mono);
        FreeImage_ConvertToRawBits(
            result.scanLine(0), dib, result.bytesPerLine(), 1, 0, 0, 0, true
        );
        return result;
    }
    case 4: { /* NOTE: QImage do not support 4-bit, convert it to 8-bit  */
        QImage result(width, height, QImage::Format_Indexed8);
        FreeImage_ConvertToRawBits(
            result.scanLine(0), dib, result.bytesPerLine(), 8, 0, 0, 0, true
        );
        return result;
    }
    case 8: {
        QImage result(width, height, QImage::Format_Indexed8);
        FreeImage_ConvertToRawBits(
            result.scanLine(0), dib, result.bytesPerLine(), 8, 0, 0, 0, true
        );
        return result;
    }
    case 16:
        if ( // 5-5-5
            (FreeImage_GetRedMask(dib)   == FI16_555_RED_MASK) &&
            (FreeImage_GetGreenMask(dib) == FI16_555_GREEN_MASK) &&
            (FreeImage_GetBlueMask(dib)  == FI16_555_BLUE_MASK)) {
            QImage result(width, height, QImage::Format_RGB555);
            FreeImage_ConvertToRawBits(
                result.scanLine(0), dib, result.bytesPerLine(), 16,
                FI16_555_RED_MASK, FI16_555_GREEN_MASK, FI16_555_BLUE_MASK,
                true
            );
            return result;
        } else { // 5-6-5
            QImage result(width, height, QImage::Format_RGB16);
            FreeImage_ConvertToRawBits(
                result.scanLine(0), dib, result.bytesPerLine(), 16,
                FI16_565_RED_MASK, FI16_565_GREEN_MASK, FI16_565_BLUE_MASK,
                true
            );
            return result;
        }
    case 24: {
        QImage result(width, height, QImage::Format_RGB32);
        FreeImage_ConvertToRawBits(
            result.scanLine(0), dib, result.bytesPerLine(), 32,
            FI_RGBA_RED_MASK, FI_RGBA_GREEN_MASK, FI_RGBA_BLUE_MASK,
            true
        );
        return result;
    }
    case 32: {
        QImage result(width, height, QImage::Format_ARGB32);
        FreeImage_ConvertToRawBits(
            result.scanLine(0), dib, result.bytesPerLine(), 32,
            FI_RGBA_RED_MASK, FI_RGBA_GREEN_MASK, FI_RGBA_BLUE_MASK,
            true
        );
        return result;
    }
    default:
        break;
    }
    return noneQImage();
}

/**
 * @brief openGiffromPath
 * @param[in]  path
 * @return void *
 * @author LMH
 * @time 2020/05/08
 * 用freeimage打开Gif图片
 */
void *openGiffromPath(const QString &path)
{
    FREE_IMAGE_FORMAT fif = FIF_GIF;
    FIBITMAP *fiBmp = FreeImage_Load(fif, path.toStdString().c_str(), GIF_DEFAULT);
    FIMULTIBITMAP *pGIF = FreeImage_OpenMultiBitmap(fif, path.toStdString().c_str(), 0, 1, 0, GIF_PLAYBACK);
    return pGIF;
}
/**
 * @brief getGifImageCount
 * @param[in]  pGIF
 * @return int
 * @author LMH
 * @time 2020/05/08
 * 返回gif一共的帧数
 */
int getGifImageCount(void *pGIF)
{
    return FreeImage_GetPageCount((FIMULTIBITMAP *)pGIF);
}
/**
 * @brief getGifImage
 * @param[in]  index
 * @param[in]  pGIF
 * @return QImage
 * @author LMH
 * @time 2020/05/08
 * 返回gif某一帧数的图片
 */
QImage getGifImage(int index, void *pGIF)
{
    FIBITMAP *tmpMap = FreeImage_LockPage((FIMULTIBITMAP *)pGIF, index);
    QImage image = freeimage::FIBitmapToQImage(tmpMap);
    FreeImage_UnlockPage((FIMULTIBITMAP *)pGIF, tmpMap, 1);
    return image;
}
}  // namespace freeimage

}  // namespace image

}  // namespace utils
