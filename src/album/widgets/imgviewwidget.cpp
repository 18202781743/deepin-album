/*
 * Copyright (C) 2020 ~ 2021 Uniontech Software Technology Co., Ltd.
 *
 * Author:     ZhangYong <zhangyong@uniontech.com>
 *
 * Maintainer: ZhangYong <ZhangYong@uniontech.com>
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
#include "imgviewwidget.h"
#include "application.h"
#include "utils/baseutils.h"
#include "utils/imageutils.h"
#include "utils/unionimage.h"

#include "dbmanager/dbmanager.h"
#include "controller/configsetter.h"
#include "widgets/elidedlabel.h"
#include "controller/signalmanager.h"
#include "imageengine/imageengineapi.h"
#include "ac-desktop-define.h"

#include <QTimer>
#include <QScroller>
#include <QScrollBar>
#include <QFileInfo>
#include <QHBoxLayout>
#include <QDebug>
#include <QPainterPath>
#include <DLabel>
#include <QAbstractItemModel>
#include <DImageButton>
#include <DThumbnailProvider>
#include <DApplicationHelper>
#include <DSpinner>
#include <QtMath>

#include "imgviewlistview.h"

DWIDGET_USE_NAMESPACE

MyImageListWidget::MyImageListWidget(QWidget *parent)
    : QWidget(parent)
{
    QHBoxLayout *hb = new QHBoxLayout(this);
    hb->setContentsMargins(0, 0, 0, 0);
    hb->setSpacing(0);
    this->setLayout(hb);
    m_listview = new ImgViewListView(this);
    m_listview->setObjectName("m_imgListWidget");
    hb->addWidget(m_listview);

    connect(m_listview, &ImgViewListView::clicked, this, &MyImageListWidget::onClicked);
    connect(m_listview, &ImgViewListView::openImg, this, &MyImageListWidget::openImg);
    connect(m_listview->horizontalScrollBar(), &QScrollBar::valueChanged, this, &MyImageListWidget::onScrollBarValueChanged);
}

MyImageListWidget::~MyImageListWidget()
{
}

void MyImageListWidget::setAllFile(QList<ItemInfo> itemInfos, QString path)
{
    m_listview->setAllFile(itemInfos, path);
    this->setVisible(itemInfos.size() > 1);
    setSelectCenter();
    emit openImg(m_listview->getSelectIndexByPath(path), path);
}

ItemInfo MyImageListWidget::getImgInfo(const QString &path)
{
    ItemInfo info;
    for (int i = 0; i < m_listview->m_model->rowCount(); i++) {
        QModelIndex indexImg = m_listview->m_model->index(i, 0);
        ItemInfo infoImg = indexImg.data(Qt::DisplayRole).value<ItemInfo>();
        if (infoImg.path == path) {
            info = infoImg;
            break;
        }
    }
    return info;
}
//将选中项移到最前面，后期可能有修改，此时获取的列表宽度不正确
void MyImageListWidget::setSelectCenter()
{
    m_listview->setSelectCenter();
}

int MyImageListWidget::getImgCount()
{
    return m_listview->m_model->rowCount();
}

void MyImageListWidget::removeCurrent()
{
    m_listview->removeCurrent();
    this->setVisible(getImgCount() > 1);
}

void MyImageListWidget::onScrollBarValueChanged(int value)
{
    QModelIndex index = m_listview->indexAt(QPoint((m_listview->width() - 15), 10));
    if (!index.isValid()) {
        index = m_listview->indexAt(QPoint((m_listview->width() - 20), 10));
    }
}

void MyImageListWidget::openNext()
{
    m_listview->openNext();
}

void MyImageListWidget::openPre()
{
    m_listview->openPre();
}

bool MyImageListWidget::isLast()
{
    return m_listview->isLast();
}

bool MyImageListWidget::isFirst()
{
    return m_listview->isFirst();
}

void MyImageListWidget::onClicked(const QModelIndex &index)
{
    m_listview->onClicked(index);
}
