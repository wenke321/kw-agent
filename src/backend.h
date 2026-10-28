#ifndef BACKEND_H
#define BACKEND_H

#include "agent_loop.h"
#include "helpers/function.h"
#include "helpers/log.h"
#include <qobject.h>

class backend : public QObject {
  Q_OBJECT

public:
  explicit backend(QObject *parent = nullptr) : QObject(parent), loop() {

    spdlog::set_level(spdlog::level::debug);

    loop.add_turn_to_qml = [&](long long _id,
                               const std::string &_user_content) {
      emit add_turn(static_cast<int>(_id),
                    QString::fromStdString(_user_content));
    };

    loop.add_step_to_qml = [&](long long _id,
                               const std::string &_reasoning_content,
                               const std::string &_assistant_out,
                               const std::string &_tool_call_json) {
      {
        LOG_INFO("add_step_to_qml\n");
      }
      QJsonParseError pe;
      QJsonDocument doc = QJsonDocument::fromJson(
          QByteArray::fromStdString(_tool_call_json), &pe);
      if (pe.error != QJsonParseError::NoError) {
        LOG_ERROR("{}\n", QString("QJsonDocument::fromJson error at %1: %2")
                              .arg(pe.offset)
                              .arg(pe.errorString())
                              .toStdString());
      }

      emit add_step(static_cast<int>(_id),
                    QString::fromUtf8(_reasoning_content),
                    QString::fromUtf8(_assistant_out), doc.toVariant());
    };
  }

  Q_INVOKABLE QString cur_dir() { return QDir::currentPath(); }

  Q_INVOKABLE void change_provider(const QString &_provider,
                                   const QString &_chat_url,
                                   const QString &_key, int _max_context) {
    loop.change_provider(_provider.toStdString(), _chat_url.toStdString(),
                         _key.toStdString(), _max_context);
  }

  Q_INVOKABLE void set_user_content() {}

  Q_INVOKABLE bool store_workspaces_sessions_jsonstr(const QString &_jsonstr) {
    return kw::store_jsonstr("workspaces_sessions", _jsonstr.toStdString(),
                             (QDir::currentPath() + "/").toStdString());
  }

  Q_INVOKABLE QVariantMap load_workspaces_sessions_json() {
    std::string workspaces_sessions_jsonstr =
        loop.get_workspaces_sessions_jsonstr();
      //{LOG_DEBUG("workspaces_sessions_jsonstr loaded from backend:\n{}",workspaces_sessions_jsonstr);}
    QVariantMap ret;

    if (workspaces_sessions_jsonstr.empty()) {
      ret["ok"] = false;
      return ret;
    }

    QJsonParseError pe;
    QJsonDocument doc = QJsonDocument::fromJson(
        QByteArray::fromStdString(workspaces_sessions_jsonstr), &pe);
    if (pe.error != QJsonParseError::NoError) {
      ret["ok"] = false;
      LOG_ERROR("{}\n", QString("QJsonDocument::fromJson error at %1: %2")
                            .arg(pe.offset)
                            .arg(pe.errorString())
                            .toStdString());
      return ret;
    }

    ret["ok"] = true;
    ret["json"] = doc.toVariant(); // 数组/对象都会自动映射到 QML
    return ret;
  }

  Q_INVOKABLE bool store_models_jsonstr(const QString &_jsonstr) {
    return kw::store_jsonstr("models", _jsonstr.toStdString(),
                             (QDir::currentPath() + "/").toStdString());
  }

  Q_INVOKABLE QVariantMap load_models_json() {
    std::string tmp, err;
    QVariantMap ret;
    if (!kw::load_jsonstr((QDir::currentPath() + "/models.json").toStdString(),
                          tmp, err)) {
      ret["ok"] = false;
      // ret["err"] = QString::fromStdString(err);
      return ret;
    }

    QJsonParseError pe;
    QJsonDocument doc =
        QJsonDocument::fromJson(QString::fromStdString(tmp).toUtf8(), &pe);
    if (pe.error != QJsonParseError::NoError) {
      ret["ok"] = false;
      LOG_ERROR("{}\n", QString("QJsonDocument::fromJson error at %1: %2")
                            .arg(pe.offset)
                            .arg(pe.errorString())
                            .toStdString());
      return ret;
    }

    ret["ok"] = true;
    ret["json"] = doc.toVariant(); // 数组/对象都会自动映射到 QML
    return ret;
  }

  Q_INVOKABLE int add_workspace(const QString &_folder_path,
                                const QString &_name) {
    return static_cast<int>(
        loop.add_workspace(_folder_path.toStdString(), _name.toStdString()));
  }

  Q_INVOKABLE bool change_workspace_name(int _w_idx, int _w_id,
                                         const QString &_name) {
    return loop.change_workspace_name(_w_idx, _w_id, _name.toStdString());
  }

  Q_INVOKABLE bool delete_workspace(int _w_idx, int _w_id) {
    return loop.delete_workspace(_w_idx, _w_id);
  }

  Q_INVOKABLE int add_session(int _w_idx, int _w_id,
                              const QString &_session_name) {
    return static_cast<int>(loop.add_session(static_cast<long long>(_w_idx),
                                             static_cast<long long>(_w_id),
                                             _session_name.toStdString()));
  }

  Q_INVOKABLE bool change_session_name(int _w_idx, int _s_idx, int _s_id,
                                       const QString &_name) {
    return loop.change_session_name(
        static_cast<long long>(_w_idx), static_cast<long long>(_s_idx),
        static_cast<long long>(_s_id), _name.toStdString());
  }

  // return turns_steps_jsonstr
  Q_INVOKABLE QVariantMap change_session(int _session_id,
                                         const QString &_path) {
    std::string turns_steps_jsonstr = loop.change_session(
        static_cast<long long>(_session_id), _path.toStdString());
    QVariantMap ret;

    if (turns_steps_jsonstr.empty()) {
      ret["ok"] = false;
      return ret;
    }

    QJsonParseError pe;
    QJsonDocument doc = QJsonDocument::fromJson(
        QByteArray::fromStdString(turns_steps_jsonstr), &pe);
    if (pe.error != QJsonParseError::NoError) {
      ret["ok"] = false;
      LOG_ERROR("{}\n", QString("QJsonDocument::fromJson error at %1: %2")
                            .arg(pe.offset)
                            .arg(pe.errorString())
                            .toStdString());
      return ret;
    }

    ret["ok"] = true;
    loop.cur_session_id = _session_id;
    ret["json"] = doc.toVariant(); // 数组/对象都会自动映射到 QML
    //{LOG_DEBUG("返回的turns_steps_json: {}",doc.toJson().toStdString());}
    return ret;
  }

  Q_INVOKABLE bool delete_session(int _w_idx, int _s_idx, int _s_id) {
    return loop.delete_session(_w_idx, _s_idx, _s_id);
  }

  Q_INVOKABLE void start_turn(const QString &_model, const QString &_effort,
                              const QString _user_content,
                              int _permission_level) {
    loop.set_before_turn(_model.toStdString(), _effort.toStdString(),
                         _permission_level, _user_content.toStdString());
    // QTimer::singleShot(0,this,[&]{this.start_turn_raw();});
    QThreadPool::globalInstance()->start([&] { loop.loop(); });
  }

  Q_INVOKABLE void start_turn_raw() {
    // loop.loop(&_continue);
    // if(_continue){
    //     QTimer::singleShot(1000,this,[=]{this.start_turn_raw();});
    // }

    QThreadPool::globalInstance()->start([&] { loop.loop(); });
  }

  Q_INVOKABLE bool checkout_session(int _cur_s_id, int _new_s_id) {
    return loop.checkout_session(static_cast<long long>(_cur_s_id),
                                 static_cast<long long>(_new_s_id));
  }

signals:

  void add_turn(int _id, const QString &_user_content);
  void add_step(int _id, const QString &_reasoning_content,
                const QString &_assistant_out, const QVariant &_tool_call_json);

private:
  kw::agent_loop loop;
  int _continue;
};

#endif // BACKEND_H
